# nix-darwin and the macOS Track

**Platforms:** `[macOS]`

nix-darwin uses the Nix module system to build and activate a macOS system
configuration. It can manage Nix, packages, shells, launchd jobs, selected
users, and many preference domains. It does not turn macOS into NixOS and
cannot replace Apple's operating-system, security, or hardware management.

## Objectives

By the end of this chapter, you should be able to:

- explain nix-darwin evaluation, build, profile, and activation architecture;
- configure packages, preferences, launchd jobs, and Home Manager;
- keep Nix, Homebrew, the App Store, and macOS responsibilities separate;
- build and inspect a host without activating it;
- use generations, rollback, and source control for recovery; and
- identify settings nix-darwin cannot safely or completely control.

## Architecture and trust boundaries

A typical flake exports:

```nix
darwinConfigurations.orion = nix-darwin.lib.darwinSystem {
  modules = [ ./configuration.nix ];
};
```

Evaluation merges modules into one configuration. Building produces a system
closure in `/nix/store`, including an activation program. `darwin-rebuild
switch` then:

1. builds the selected `darwinConfigurations.<name>.system`;
2. updates the nix-darwin system profile; and
3. runs the generated activation program as `root`.

The store build is immutable and normally unprivileged through the Nix daemon.
Activation is privileged and can write preferences, `/etc` links, launchd
definitions, shells, and other declared host state. A successful build proves
that outputs were constructed; it does not prove every activation step or GUI
preference will work on the running macOS release.

Keep these layers distinct:

- **macOS:** kernel, sealed system volume, SIP, TCC, FileVault, firmware,
  software updates, GUI frameworks, and Apple account services;
- **Nix:** immutable packages, dependency graphs, stores, and profiles;
- **nix-darwin:** supported system policy and activation on macOS;
- **Home Manager:** per-user packages, files, programs, and user agents;
- **Homebrew/App Store/vendor tools:** software outside the Nix store with
  their own metadata, update, signing, and state models.

## A current flake shape

```nix
{
  description = "Example macOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager, ... }: {
    darwinConfigurations."orion" = nix-darwin.lib.darwinSystem {
      specialArgs = { inherit inputs; };
      modules = [
        home-manager.darwinModules.home-manager
        ./configuration.nix
        {
          nixpkgs.hostPlatform = "aarch64-darwin";
          system.configurationRevision =
            self.rev or self.dirtyRev or null;
        }
      ];
    };
  };
}
```

Use `x86_64-darwin` for an Intel Mac and `aarch64-darwin` for Apple Silicon.
An Apple Silicon machine can execute some Intel software through Rosetta, but
that does not make the host platform interchangeable.

Pin input revisions in `flake.lock`, or use immutable revision URLs when a
lock cannot yet be generated. Make nix-darwin and Home Manager follow the same
Nixpkgs input unless a documented compatibility reason requires otherwise.

## Host configuration

```nix
{ pkgs, ... }:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  system.primaryUser = "alice";
  users.users.alice.home = "/Users/alice";

  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  programs.zsh.enable = true;

  system.stateVersion = 7;
}
```

`system.primaryUser` identifies the account for options that need one
particular user's context. It is a transition mechanism, not a claim that the
host has only one user. Set it explicitly when an enabled option requires it.
Do not use configuration to create or mutate a real macOS account until you
understand UID, SecureToken, FileVault, and directory-service implications.

`system.stateVersion` is an integer in nix-darwin, unlike the string used by
NixOS and Home Manager. It selects compatibility defaults. For a new
installation, use the value recommended by the pinned nix-darwin release.
After first activation, do not bump it merely because inputs were updated.
Read the changelog:

```console
darwin-rebuild changelog --flake .#orion
```

Home Manager has a separate `home.stateVersion`.

## Packages and applications

System-wide Nix packages belong in:

```nix
environment.systemPackages = with pkgs; [
  git
  jq
  ripgrep
];
```

User-specific tools belong in `home.packages`. Prefer one owner for each
package to avoid ambiguity. Nix packages are selected by the pinned Nixpkgs
revision and are not updated by an in-app updater.

Graphical application packaging on macOS has extra constraints: app bundles
must be discoverable, some applications expect writable installation
locations, and code signing, notarization, quarantine, entitlements, TCC, and
automatic updates may matter. A Nixpkgs package is not automatically
equivalent to a Homebrew cask or App Store installation.

## macOS defaults

nix-darwin provides typed options for supported preference keys:

```nix
system.defaults = {
  NSGlobalDomain = {
    AppleShowAllExtensions = true;
    InitialKeyRepeat = 15;
    KeyRepeat = 2;
  };

  dock = {
    autohide = true;
    show-recents = false;
  };

  finder = {
    AppleShowAllExtensions = true;
    FXPreferredViewStyle = "Nlsv";
  };
};
```

Use typed options when available. `system.defaults.CustomUserPreferences` and
related escape hatches can express unsupported keys, but they are easier to
mis-type and may change across macOS versions.

Apple preference behavior is not fully transactional:

- cached values may require restarting the affected application;
- Dock or Finder changes may require restarting those processes;
- some settings apply only after logout or login;
- managed-device policy may override local values;
- macOS upgrades can rename, ignore, or rewrite keys; and
- an application can write a preference after activation.

Before declaring an unfamiliar key, establish its domain, exact type, and
behavior on the target macOS release. Avoid copying an old `defaults write`
snippet without verification.

## launchd agents and daemons

macOS uses launchd instead of systemd. A daemon belongs to the system domain
and typically runs independently of GUI login:

```nix
launchd.daemons.example-clock = {
  serviceConfig = {
    ProgramArguments = [
      "${pkgs.coreutils}/bin/date"
    ];
    StartInterval = 3600;
    RunAtLoad = true;
    StandardOutPath = "/var/log/example-clock.log";
    StandardErrorPath = "/var/log/example-clock.err";
  };
};
```

A nix-darwin agent belongs to a user-oriented launchd domain:

```nix
launchd.user.agents.example-notifier = {
  serviceConfig = {
    ProgramArguments = [
      "${pkgs.bash}/bin/bash"
      "-lc"
      "printf '%s\n' ready"
    ];
    RunAtLoad = true;
  };
};
```

Use the exact options from the pinned nix-darwin manual. Home Manager also has
`launchd.agents` for per-user configuration; choose one layer to own a given
label.

launchd does not start commands through your interactive shell unless you
explicitly ask it to. Prefer `ProgramArguments`, absolute store paths, and
explicit environment variables. Avoid shell strings when an argument vector
is sufficient.

Inspect jobs with:

```console
sudo launchctl print system
launchctl print gui/$(id -u)
log show --last 10m --predicate 'process == "launchd"'
```

Use `launchctl print system/<label>` or `gui/<uid>/<label>` after confirming
the generated label. Log files need safe ownership, permissions, and rotation.
A job repeatedly failing at startup may be throttled; read its launchd state
and stderr rather than adding sleeps.

## Home Manager integration

```nix
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.alice = {
      home.username = "alice";
      home.homeDirectory = "/Users/alice";
      home.stateVersion = "26.05";
      programs.git.enable = true;
    };
  };
}
```

Integrated Home Manager activation follows the nix-darwin system generation.
This is useful when host and user policy should move together. Standalone Home
Manager is valid when users need independent lifecycle and privileges. Do not
manage the same file or launchd label from both modes.

## The Homebrew boundary

nix-darwin has a `homebrew` module that can invoke Homebrew during activation:

```nix
homebrew = {
  enable = true;
  brews = [ "mas" ];
  casks = [ "example-app" ];
  onActivation = {
    autoUpdate = false;
    upgrade = false;
    cleanup = "none";
  };
};
```

This is orchestration, not conversion into Nix derivations. Formulae, casks,
taps, bottles, mutable prefixes, analytics, and update behavior remain
Homebrew concerns. Enabling cleanup can remove manually installed software;
enabling updates can make activation network-dependent and less predictable.
Start with conservative `onActivation` settings and document ownership.

Use Nix when the package is well-supported and reproducibility matters. Keep
Homebrew for software whose macOS packaging or vendor distribution works
better there. Use the App Store when licensing, receipts, entitlements, or
Apple-managed updates require it. Avoid installing the same application
through multiple managers.

Third-party projects such as nix-homebrew can pin Homebrew infrastructure, but
they do not make every cask immutable or reproducible. They must be evaluated
and pinned as separate dependencies.

## Safe build, activation, and inspection

From a flake directory:

```console
nix flake metadata
nix eval .#darwinConfigurations.orion.config.system.stateVersion
nix build .#darwinConfigurations.orion.system
```

If `darwin-rebuild` is already installed:

```console
darwin-rebuild build --flake .#orion
```

These build commands do not activate the result. Inspect the closure:

```console
readlink result
nix path-info -Sh ./result
./result/sw/bin/darwin-option system.defaults
```

The exact `darwin-option` location can vary; use the one from the pinned
nix-darwin package if needed.

Only after reviewing changes should an administrator explicitly activate:

```console
sudo darwin-rebuild switch --flake .#orion
```

`switch` updates the profile and runs activation. `activate` reruns the
activation program associated with the currently selected nix-darwin
installation. `check` runs activation in nix-darwin's check mode and still
requires root; it is not equivalent to a pure build and should not be treated
as a no-side-effect sandbox.

Never put `sudo darwin-rebuild switch` in a flake output, shell hook, login
script, editor task, or automatic checkout hook. Evaluation and development
shell entry should remain non-mutating.

## Generations, rollback, and recovery

List system profile generations:

```console
sudo darwin-rebuild --list-generations
```

Roll the system profile back and activate the selected previous generation:

```console
sudo darwin-rebuild --rollback
```

Select a specific retained generation:

```console
sudo darwin-rebuild --switch-generation 42
```

These operations change the selected built generation and run its activation.
They do not revert:

- the Git working tree or `flake.lock`;
- Homebrew or App Store upgrades;
- application databases or preferences not managed by that generation;
- macOS updates, TCC decisions, FileVault state, or directory services; or
- destructive side effects from custom activation scripts.

After rollback, fix or revert the declarative source and build again. Retain a
known-good generation until the new configuration has survived login, reboot,
and service checks. Garbage collection can remove unreferenced store paths,
so inspect generations before pruning.

### Recovery sequence

If activation fails but the shell remains usable:

1. save the complete error output;
2. do not repeatedly run the failing activation;
3. run `sudo darwin-rebuild --list-generations`;
4. select a known-good generation with `--switch-generation`;
5. verify Nix daemon, shell, network, and launchd state;
6. restore mutable data separately if needed; and
7. correct the source before the next switch.

If `darwin-rebuild` is missing from `PATH`, invoke the executable from the
current system profile or a retained generation. Inspect:

```console
ls -l /nix/var/nix/profiles/system*
readlink /nix/var/nix/profiles/system
```

Do not hand-edit profile symlinks unless following current official recovery
instructions. If Nix itself is unavailable, use macOS Recovery or another
administrator account as appropriate, preserve `/nix` and configuration
source, and diagnose before reinstalling.

The official uninstaller is:

```console
sudo darwin-uninstaller
```

or, when appropriate, the command documented by the pinned nix-darwin
release. Uninstalling nix-darwin is not the same as uninstalling Nix, Homebrew,
or restoring every preference to its historical value.

## Upgrades and migration

Treat updates as source changes:

```console
nix flake update
nix flake check
darwin-rebuild build --flake .#orion
darwin-rebuild changelog --flake .#orion
```

Then review the lock diff, changelogs, renamed options, package changes, and
generated system. Upgrade a disposable or secondary Mac first when possible.
Do not combine a macOS major upgrade, Nix installer migration, nix-darwin
state-version change, and large package update in one recovery boundary.

Keep `system.stateVersion` stable. If a release note explicitly requires a
state migration, back up affected state, retain the old generation, test the
migration, and document whether rollback also requires restoring data.

## Limits and non-goals

nix-darwin cannot guarantee control over:

- SIP, the sealed system volume, firmware, and the macOS kernel;
- all TCC privacy grants, SecureToken, FileVault, and Apple ID state;
- Mobile Device Management policy imposed by an organization;
- every undocumented or version-specific preference key;
- application-internal mutable data and cloud synchronization;
- App Store licensing and vendor updater semantics;
- hardware recovery, Activation Lock, or macOS Recovery; or
- arbitrary side effects introduced by custom activation scripts.

Do not weaken SIP, Gatekeeper, quarantine, or TCC merely to make a package
work. Understand the security consequence and prefer supported packaging.

## Failure scenarios

### Unknown option or type mismatch

Build with a trace and check the pinned manual:

```console
darwin-rebuild build --flake .#orion --show-trace
```

The option may have moved, changed type, or require `system.primaryUser`.
Follow release notes rather than cargo-culting an older example.

### Preference appears unchanged

Confirm the domain, key, type, and generated value. Restart the application or
log out only when its documented behavior requires that. Check MDM policy and
whether the application rewrote the key. Do not repeatedly activate as root
without new evidence.

### launchd job fails

Inspect its exact domain and label, stderr, ownership, executable path, and
environment. Test the executable directly with a minimal environment. A GUI
agent cannot be debugged as though it were a system daemon.

### Homebrew activation fails

The Nix system may have built successfully while Homebrew's network or mutable
prefix operation failed. Inspect Homebrew independently, avoid destructive
cleanup, and retry only after understanding whether activation partially
changed the prefix.

### Shell access breaks

Keep one administrator terminal open during risky shell changes. Ensure the
shell is declared and accepted by macOS before making it a login shell.
Recover from another administrator account or macOS Recovery if login is no
longer possible.

## Common misconceptions

- **“nix-darwin is NixOS for Mac.”** macOS remains the operating system.
- **“Build and switch are both harmless evaluation.”** `switch` runs
  privileged activation and mutates the host.
- **“Rollback restores everything.”** It restores the managed system
  generation, not external mutable state.
- **“All `defaults` keys are stable APIs.”** Many are undocumented,
  application-owned, cached, or release-specific.
- **“launchd reads my shell setup.”** Jobs need explicit paths and
  environments.
- **“Declaring Homebrew makes casks reproducible Nix packages.”** Homebrew
  keeps its own mutable model.
- **“`system.stateVersion` is the nix-darwin release.”** It is a compatibility
  selector and should normally stay fixed.
- **“Root activation can safely manage any user setting.”** User domains,
  sessions, ownership, TCC, and preference caches impose real boundaries.

## Exercises

1. Evaluate the safe example in `tracks/macos` and print its host platform,
   primary user, and both state versions without activation.
2. Add one command-line package to the example, build the system closure, and
   inspect its store path.
3. Draft a launchd agent and daemon for the same command. Explain why their
   domains and privilege differ.
4. Classify five applications as Nix, Homebrew, App Store, or vendor-managed,
   and justify each boundary.
5. Find one typed `system.defaults` option in the pinned manual and document
   how to verify it after activation on a disposable host.
6. Write a recovery checklist that includes a retained generation, source
   rollback, and mutable-data restore.
7. Compare standalone and integrated Home Manager for a multi-user Mac.
8. Plan a nix-darwin input update without changing `system.stateVersion`.

## Official references

- [nix-darwin manual](https://nix-darwin.github.io/nix-darwin/manual/)
- [nix-darwin repository](https://github.com/nix-darwin/nix-darwin)
- [nix-darwin flake template](https://github.com/nix-darwin/nix-darwin/tree/master/modules/examples/flake)
- [Home Manager nix-darwin module](https://nix-community.github.io/home-manager/index.xhtml#sec-install-nix-darwin-module)
- [Home Manager options](https://nix-community.github.io/home-manager/options.xhtml)
- [Nix flakes](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake)
- [Nix store garbage collection](https://nix.dev/manual/nix/latest/package-management/garbage-collection)
- [`launchd` manual page](https://keith.github.io/xcode-man-pages/launchd.8.html)
- [`launchctl` manual page](https://keith.github.io/xcode-man-pages/launchctl.1.html)
- [Apple Platform Security](https://support.apple.com/guide/security/welcome/web)
- [Homebrew documentation](https://docs.brew.sh/)
