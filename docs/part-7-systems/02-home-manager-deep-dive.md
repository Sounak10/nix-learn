# Home Manager Deep Dive

**Platforms:** `[Linux]` `[macOS]` `[NixOS]`

Home Manager applies the Nix module system to one user's environment. It can
install packages, generate dotfiles, configure supported programs, and define
user services. It does not replace the operating system, a secret manager, or
backups.

## Objectives

By the end of this chapter, you should be able to:

- choose standalone, NixOS-integrated, or nix-darwin-integrated operation;
- manage packages, files, programs, and user services declaratively;
- build and inspect a configuration before activating it;
- reason about generations, rollback, garbage collection, and file conflicts;
- preserve `home.stateVersion` and migrate deliberately; and
- test module behavior without risking a real home directory.

## The Home Manager model

A Home Manager configuration is a Nix module. Modules contribute options and
configuration; the module system merges them and produces an activation
package. Activation installs a new user profile generation and reconciles
managed files in the home directory.

The boundary matters:

- Nix builds immutable store objects.
- The profile selects one generation of those objects.
- Activation creates links and performs declared activation steps.
- Applications still create mutable caches, databases, history, and state.

A generation rollback restores the earlier managed profile and files. It does
not restore mutable application data or the source repository that produced
the generation.

## Three deployment modes

### Standalone

Standalone Home Manager works on NixOS, other Linux distributions, and macOS.
The user owns the Home Manager lifecycle and can normally activate without a
system rebuild.

```nix
{
  description = "Standalone home";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, ... }: {
    homeConfigurations."alice@example" =
      home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        modules = [ ./home.nix ];
      };
  };
}
```

Build first, then activate only after inspecting the result:

```console
nix build .#homeConfigurations."alice@example".activationPackage
./result/activate
```

If the `home-manager` command is installed, the normal workflow is:

```console
home-manager build --flake .#alice@example
home-manager switch --flake .#alice@example
```

`build` is non-activating. `switch` builds and activates. Running the generated
`activate` program is also activation; it is not a dry run.

### NixOS integration

The NixOS module makes the home configuration part of the system evaluation
and activation:

```nix
{
  imports = [ home-manager.nixosModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.alice = import ./home/alice.nix;
  };
}
```

`useGlobalPkgs = true` shares the system's configured `pkgs`, overlays, and
unfree policy. Without it, Home Manager creates a separate package set.
`useUserPackages = true` installs user packages through
`users.users.<name>.packages`, placing them in the system-managed user profile.

Build and test through the host:

```console
sudo nixos-rebuild build --flake .#atlas
sudo nixos-rebuild test --flake .#atlas
sudo nixos-rebuild switch --flake .#atlas
```

The home and host then share the system generation lifecycle. A user cannot
independently switch the integrated configuration unless system policy grants
that ability.

### nix-darwin integration

The equivalent macOS module is:

```nix
{
  imports = [ home-manager.darwinModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.alice = import ./home/alice.nix;
  };
}
```

Build without activation:

```console
darwin-rebuild build --flake .#orion
```

Activation is a privileged, explicit operation:

```console
sudo darwin-rebuild switch --flake .#orion
```

The integrated home follows the nix-darwin generation. macOS user agents and
preferences still obey launchd, login-session, sandbox, and GUI application
rules.

## A practical home module

```nix
{ config, pkgs, ... }:
{
  home.username = "alice";
  home.homeDirectory = "/Users/alice"; # Use /home/alice on typical Linux.
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    jq
    ripgrep
  ];

  programs.git = {
    enable = true;
    settings = {
      user.name = "Alice Example";
      init.defaultBranch = "main";
    };
  };

  home.sessionVariables.EDITOR = "vim";

  home.file.".config/example/config.toml".text = ''
    color = true
  '';

  xdg.configFile."example/rules.txt".source = ./files/rules.txt;

  home.activation.reportExample =
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD echo "Home Manager prepared the example configuration"
    '';
}
```

Prefer a program module over hand-written files when its options express what
you need. Program modules can account for platform differences and compose
settings safely. Use `home.file` for arbitrary home-relative paths and
`xdg.configFile` for XDG configuration.

The source of `home.file.<name>.source` enters the Nix store. Never put
plaintext passwords, private keys, tokens, or decrypted secret files there.
The same warning applies to `.text`, command-line arguments, derivations, and
flake source.

### File ownership and conflicts

Home Manager generally refuses to replace an existing unmanaged file. That
failure is protective. Before the first activation:

```console
ls -la ~/.config/example
cp -a ~/.config/example ~/.config/example.pre-home-manager
```

Then compare the old file, import desired settings, move it aside, and retry.
In integrated mode an administrator can configure:

```nix
home-manager.backupFileExtension = "hm-backup";
```

Backups are not versioned storage, and a repeated collision may itself
conflict. Do not enable overwrite behavior casually. Standalone CLI releases
may expose a backup extension flag; consult the pinned manual rather than
assuming the flag is available in every release.

## Packages and package-set policy

`home.packages` is for user-scoped command-line tools and applications:

```nix
home.packages = [
  pkgs.fd
  pkgs.shellcheck
];
```

Use system configuration for boot-critical software, system daemons, shared
policy, privileged configuration, and packages required before user
activation. On macOS, an application package in the Nix store does not
automatically behave exactly like an App Store or Homebrew cask; application
discovery, quarantine, signing, and update mechanisms differ.

Keep Home Manager and Nixpkgs release families compatible. With flakes,
`home-manager.inputs.nixpkgs.follows = "nixpkgs"` gives both the same pin.
Update the lock deliberately, review release notes, and test before switching:

```console
nix flake lock --update-input nixpkgs --update-input home-manager
nix flake check
home-manager build --flake .#alice@example
```

Commit the lock file so another machine evaluates the same input revisions.

## User services

On Linux, Home Manager commonly emits systemd user units:

```nix
systemd.user.services.example-ticker = {
  Unit.Description = "Example periodic worker";
  Service = {
    ExecStart = "${pkgs.coreutils}/bin/date";
    Type = "oneshot";
  };
};

systemd.user.timers.example-ticker = {
  Unit.Description = "Run the example worker hourly";
  Timer.OnCalendar = "hourly";
  Install.WantedBy = [ "timers.target" ];
};
```

Inspect it with:

```console
systemctl --user status example-ticker.service
journalctl --user -u example-ticker.service
```

On macOS, Home Manager can emit launchd user agents:

```nix
launchd.agents.example-ticker = {
  enable = true;
  config = {
    ProgramArguments = [
      "${pkgs.coreutils}/bin/date"
    ];
    StartInterval = 3600;
    RunAtLoad = true;
    StandardOutPath = "/tmp/example-ticker.out";
    StandardErrorPath = "/tmp/example-ticker.err";
  };
};
```

Inspect a GUI user's domain with:

```console
launchctl print gui/$(id -u)
launchctl print gui/$(id -u)/org.nix-community.home.example-ticker
```

Exact labels are generated by the module and may differ; inspect the built
activation package or `launchctl print`. A user agent is not a system daemon.
It runs in a user's launchd domain and may depend on login state. Use absolute
store paths rather than assuming an interactive shell `PATH`.

## Generations, rollback, and garbage collection

Standalone installations can list generations:

```console
home-manager generations
```

The output contains an activation command for each retained generation. To
roll back, run the selected older generation's `activate` program. Some
versions also provide:

```console
home-manager switch --rollback
```

Check the pinned CLI help before relying on that convenience:

```console
home-manager switch --help
```

With NixOS or nix-darwin integration, roll back the corresponding system
generation. The integrated home is activated with that generation.

Garbage collection can remove unreferenced generations and store paths:

```console
home-manager expire-generations "-30 days"
nix store gc
```

Review `home-manager expire-generations --help` and retain a known-good
generation before pruning. A generation is not a backup of mutable files,
mail, browser profiles, databases, or Git working trees.

## State versions and migration

`home.stateVersion` selects compatibility defaults for stateful behavior. It
is not the Home Manager package version:

```nix
home.stateVersion = "26.05";
```

For a new configuration, use the release documented by the pinned Home
Manager version. Once set, leave it unchanged during ordinary upgrades.
Raising it may change file locations, formats, or module defaults.

A controlled migration is:

1. commit configuration and lock file;
2. back up mutable application data;
3. read every intervening Home Manager release note;
4. build with the old state version;
5. change the state version only when a documented migration requires it;
6. inspect the activation diff and build result;
7. activate on a non-critical account or machine first;
8. verify application data and services; and
9. keep the prior generation and data backup until validation is complete.

Rolling back a generation does not reverse an application's one-way database
migration. Restore that data from an application-aware backup if necessary.

## Testing without touching a real home

Evaluation catches unknown options, type errors, and assertions:

```console
nix eval .#homeConfigurations."alice@example".config.home.username
nix eval .#homeConfigurations."alice@example".config.home.stateVersion
```

Building catches derivation and generated-file failures:

```console
nix build .#homeConfigurations."alice@example".activationPackage
```

Inspect before activation:

```console
readlink result
find result -maxdepth 2 -type f -o -type l
```

For module regression tests, evaluate a synthetic configuration rather than
using a real home:

```nix
home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  modules = [
    ./home.nix
    {
      home.username = "test-user";
      home.homeDirectory = "/tmp/test-home";
    }
  ];
}
```

Do not execute its activation package merely because the home path is under
`/tmp`; activation remains a mutation. For end-to-end Linux behavior, use a
disposable VM or container with a test user. macOS GUI and launchd behavior
requires a disposable macOS account or machine for meaningful runtime tests.

## Failure and recovery

### Evaluation fails

Read the first meaningful assertion or option error:

```console
home-manager build --flake .#alice@example --show-trace
nix flake metadata
```

Confirm the output name, platform, input revisions, and renamed options.
Consult release notes before adding compatibility workarounds.

### Activation reports an existing file

Stop and inspect both versions. Back up the unmanaged file, merge its desired
content into the declaration, then move it aside. Do not delete it blindly and
do not force recursive ownership over the home directory.

### A program breaks after activation

Activate the prior Home Manager generation, or roll back the integrated
system generation. Then restore mutable data separately if the application
migrated it. Fix the source configuration; rollback does not edit source.

### A user service fails

Inspect the platform service manager, generated unit or plist, logs,
permissions, and absolute executable paths. Reproduce the command with a
minimal environment. Interactive shell initialization is not guaranteed.

### The `home-manager` command disappeared

For a flake configuration, the activation package remains directly buildable:

```console
nix run github:nix-community/home-manager -- \
  build --flake .#alice@example
```

For strict reproducibility, invoke the pinned Home Manager input from your
flake rather than an unpinned remote reference.

## Common misconceptions

- **“Home Manager owns the whole home directory.”** It owns only declared
  paths and profile content; applications retain mutable state.
- **“Rollback restores my data.”** It restores managed generations, not
  external databases or documents.
- **“`home.stateVersion` should be bumped on every update.”** It should remain
  stable unless a reviewed migration requires a change.
- **“Standalone is less declarative.”** It uses the same module model; only
  activation ownership and lifecycle differ.
- **“Integrated mode makes every user a system administrator.”** Host
  activation still follows NixOS or nix-darwin privilege policy.
- **“A `.text` option is safe for secrets.”** Generated text normally enters
  the readable Nix store.
- **“A successful evaluation proves activation is safe.”** Evaluation cannot
  detect every collision, permission issue, service failure, or data migration.

## Exercises

1. Create a standalone flake that manages one package, one program module, and
   one XDG file. Build it without activation.
2. Add the same home module to a disposable NixOS VM through the NixOS module.
3. Add an hourly service appropriate to your platform and identify its logs.
4. Create an unmanaged target file and observe Home Manager's collision
   behavior in a disposable account.
5. List generations, retain one known-good generation, and explain what
   garbage collection can remove.
6. Read the release notes between your configured state version and current
   Home Manager. Draft, but do not perform, a migration checklist.
7. Explain which of your packages belong in `home.packages`, system packages,
   or outside Nix entirely.
8. Write an evaluation command that confirms username, home directory, and
   state version without activation.

## Official references

- [Home Manager manual](https://nix-community.github.io/home-manager/)
- [Home Manager options](https://nix-community.github.io/home-manager/options.xhtml)
- [Home Manager flake standalone setup](https://nix-community.github.io/home-manager/index.xhtml#ch-nix-flakes)
- [Home Manager NixOS module](https://nix-community.github.io/home-manager/index.xhtml#sec-install-nixos-module)
- [Home Manager nix-darwin module](https://nix-community.github.io/home-manager/index.xhtml#sec-install-nix-darwin-module)
- [Home Manager release notes](https://nix-community.github.io/home-manager/release-notes.xhtml)
- [Home Manager repository](https://github.com/nix-community/home-manager)
- [Nix profiles](https://nix.dev/manual/nix/latest/package-management/profiles)
- [Nix garbage collection](https://nix.dev/manual/nix/latest/package-management/garbage-collection)
