# Part 7 — Declarative Systems

## Chapter 1: Installing and Configuring NixOS

**Platforms:** `[NixOS]` `[Linux]`

### Objectives

- Install NixOS without losing track of disk, boot, and network assumptions.
- Structure a configuration around generated hardware facts and intentional policy.
- Validate a system before switching to it.

### Installation workflow

Back up data and verify the target disk before any destructive action. A typical manual installation is:

1. boot matching NixOS installation media;
2. establish networking and time;
3. partition the correct disk;
4. create filesystems and swap;
5. mount the future root at `/mnt` and boot filesystem beneath it;
6. run `nixos-generate-config --root /mnt`;
7. edit `/mnt/etc/nixos/configuration.nix`;
8. run `nixos-install`;
9. set credentials through the installer’s supported workflow and reboot.

Partition commands are intentionally not copied here: BIOS versus UEFI, encryption, RAID, disko-managed layouts, and existing data materially change them. Follow the installation manual for the target and confirm device identifiers.

`hardware-configuration.nix` records detected filesystems, initrd modules, and hardware facts. Keep it imported, review it, and avoid using it as a general policy file:

```nix
{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "atlas";
  time.timeZone = "Europe/Berlin";
  users.users.alice = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    packages = [ pkgs.git ];
  };

  system.stateVersion = "24.11";
}
```

`system.stateVersion` selects compatibility defaults for stateful services and paths. It is not the installed NixOS version and should not be bumped automatically during upgrades. Read release notes before changing it.

### Evaluation and activation

For classic configuration:

```console
sudo nixos-rebuild dry-build
sudo nixos-rebuild test
sudo nixos-rebuild switch
```

For flakes:

```console
sudo nixos-rebuild switch --flake .#atlas
```

`build` creates the system without activating it. `test` activates for the running boot only. `switch` activates now and sets the default boot entry. `boot` builds and sets the next/default boot configuration without changing the currently running system. Use `test` for risky remote changes, but recognize that networking or SSH changes can still disconnect the session.

### Common misconceptions

- **“Generated hardware configuration is disposable.”** It contains boot-critical detected settings.
- **“`stateVersion` should match every upgrade.”** It preserves compatibility for stateful defaults.
- **“Declarative users automatically get secure passwords.”** Credential provisioning must be designed explicitly.
- **“A successful build proves the machine will boot.”** Bootloader, initrd, storage, firmware, and activation need real validation.

### Recap

Installation joins imperative disk preparation to declarative system policy. Preserve hardware facts, treat `stateVersion` carefully, and choose build/test/switch/boot according to activation risk.

### Exercises

1. Draft a host configuration that separates hardware, boot, users, and services.
2. Explain the safest rebuild action for a remote kernel upgrade.
3. Compare UEFI and legacy BIOS prerequisites using the installation manual.
4. Write an upgrade checklist that leaves `stateVersion` unchanged by default.

### Official links

- [NixOS installation](https://nixos.org/manual/nixos/stable/#ch-installation)
- [NixOS configuration](https://nixos.org/manual/nixos/stable/#ch-configuration)
- [`nixos-rebuild`](https://nixos.org/manual/nixos/stable/#sec-changing-config)
- [NixOS release notes](https://nixos.org/manual/nixos/stable/release-notes.html)

## Chapter 2: Generations, Boot, and Recovery

**Platforms:** `[NixOS]` `[Linux]`

### Objectives

- Understand system profiles and generations.
- Recover from failed activation or boot.
- Garbage-collect without deleting required rollback paths.

### Profiles and generations

Every successful system switch creates a generation in the system profile. Bootloader entries normally retain selectable generations. Inspect and roll back:

```console
sudo nixos-rebuild list-generations
sudo nixos-rebuild switch --rollback
```

At boot, select an older generation when the new system fails before login. A rollback changes the active system profile; it does not revert source files or a flake lock. After recovery, correct the declarative source and rebuild.

The boot chain includes firmware, bootloader, kernel, initrd, root mounting, stage 2, and systemd targets. Place storage drivers and unlock logic needed before root in initrd configuration. A service required only after root belongs in the normal system.

Nix store garbage collection removes unreachable paths. Profiles and generations are roots, so retaining generations retains their closures:

```console
nix path-info -Sh /run/current-system
sudo nixos-rebuild list-generations
```

`sudo nix-collect-garbage --delete-older-than 30d` also removes eligible
profile generations, so it can delete an older known-good rollback. Before
running it, verify generation ages and create a separate GC root for any
rollback that must survive. Store optimization deduplicates identical files;
garbage collection deletes unreachable store paths. These are separate
operations.

### Activation safety

Activation scripts should be idempotent and avoid destructive migration without backups. Systemd service restart behavior is derived from unit changes and module logic, but applications may need explicit migration or restart policy. For remote machines, keep an out-of-band console and stage firewall, SSH, storage, and bootloader changes separately.

### Common misconceptions

- **“Rollback restores `/etc/nixos`.”** It changes the system profile, not configuration source.
- **“The store keeps every build forever.”** Unreachable paths may be garbage-collected.
- **“If a generation exists, its source repository is preserved.”** Store outputs remain while rooted; your Git history and secrets need separate retention.
- **“Activation is transactional for all external state.”** Nix atomically changes profiles, but database migrations and service side effects are not automatically reversible.

### Recap

Generations provide profile-level rollback and boot choices, not source-control or data rollback. Retain known-good roots, understand the boot chain, and design state migrations separately.

### Exercises

1. Locate the current system profile and its generation links.
2. Practice selecting an older generation in a disposable VM.
3. Estimate closure sizes before deleting old generations.
4. Identify state changes that a profile rollback cannot undo.

### Official links

- [NixOS rollback](https://nixos.org/manual/nixos/stable/#sec-rollback)
- [Booting](https://nixos.org/manual/nixos/stable/#ch-booting)
- [Garbage collection](https://nix.dev/manual/nix/latest/package-management/garbage-collection)
- [Nix profiles](https://nix.dev/manual/nix/latest/package-management/profiles)

## Chapter 3: Services, Security, and Secrets

**Platforms:** `[NixOS]` `[Linux]`

### Objectives

- Configure services through NixOS options and systemd units.
- Apply least privilege at users, network, and service boundaries.
- Keep secret material out of world-readable store paths.

### Services and systemd

Prefer an existing NixOS service module:

```nix
services.openssh = {
  enable = true;
  settings = {
    PasswordAuthentication = false;
    PermitRootLogin = "no";
  };
};

networking.firewall.allowedTCPPorts = [ 22 ];
```

Enabling a daemon does not always open the firewall; inspect module options. For custom units:

```nix
systemd.services.acme = {
  description = "Example static-file service";
  wantedBy = [ "multi-user.target" ];
  after = [ "network-online.target" ];
  wants = [ "network-online.target" ];
  serviceConfig = {
    ExecStart = "${pkgs.busybox}/bin/httpd -f -p 8080 -h /var/lib/acme";
    DynamicUser = true;
    StateDirectory = "acme";
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    Restart = "on-failure";
  };
};
```

Use absolute store paths in unit commands. `after` orders units but does not pull them in; pair it with `wants` or `requires` when dependency semantics demand it. Harden with systemd sandboxing, dedicated identities, limited capabilities, read/write path restrictions, and NixOS firewall policy. Test hardening because applications may legitimately require broader access.

### Secrets caveat

The Nix store is generally readable by local users. Any literal secret interpolated into a derivation, generated config, module option that becomes a store file, command line, or flake source may be exposed and retained in history.

Safe patterns deliver secrets at activation/runtime:

- provision a root-readable file outside the store;
- use systemd credentials where supported;
- decrypt an encrypted declaration on the target using tools such as `sops-nix` or `agenix`;
- fetch from an authenticated secret manager at runtime with carefully scoped identity.

Those tools are third-party integrations, not magical encryption of already leaked store values. Keep decryption keys off the repository, set ownership and mode, avoid command-line secret arguments, and plan rotation and revocation. Flake inputs and Git history are not suitable secret stores, even for deleted files.

Password hash options are less sensitive than plaintext passwords but still enable offline guessing and should be handled deliberately. Initial-password convenience options are inappropriate for enduring production policy.

### Common misconceptions

- **“A Nix file with mode `0600` keeps an interpolated secret private.”** Its store copy can still be readable.
- **“Enabling a service opens only required ports.”** Firewall integration varies by module and option.
- **“`after` means the other unit is started.”** It is ordering, not requirement.
- **“Declarative security eliminates operational security.”** Key custody, patching, monitoring, and incident response remain essential.

### Recap

Use service modules, explicit network policy, and systemd hardening. Deliver secrets outside the store at runtime and treat rotation, permissions, logs, and backups as part of the design.

### Exercises

1. Harden a custom systemd service and document each restriction.
2. Search a built system closure for an intentionally fake secret, then remove the leak.
3. Design secret delivery for a database password with rotation.
4. Verify whether a chosen service module modifies the firewall.

### Official links

- [NixOS service management](https://nixos.org/manual/nixos/stable/#sec-systemd)
- [NixOS security](https://nixos.org/manual/nixos/stable/#ch-security)
- [NixOS options search](https://search.nixos.org/options)
- [systemd credentials](https://systemd.io/CREDENTIALS/)
- [systemd unit hardening](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html)

## Chapter 4: Containers and NixOS VM Tests

**Platforms:** `[NixOS]` `[Linux]`

### Objectives

- Choose between NixOS containers, OCI images, and virtual machines.
- Write machine-level integration tests.
- Understand isolation boundaries and test limitations.

### Isolation choices

NixOS containers use Linux namespaces and share the host kernel. They integrate with NixOS configuration and are lightweight:

```nix
containers.web = {
  autoStart = true;
  privateNetwork = true;
  hostAddress = "10.10.0.1";
  localAddress = "10.10.0.2";
  config = { pkgs, ... }: {
    services.nginx.enable = true;
    networking.firewall.allowedTCPPorts = [ 80 ];
    system.stateVersion = "24.11";
  };
};
```

They are not a virtual-machine security boundary. Kernel vulnerabilities and host configuration remain shared. OCI images built with Nixpkgs container tools target Docker/Podman-style runtimes and require separate runtime policy. Virtual machines emulate or virtualize hardware and run a guest kernel, providing a stronger boundary at greater cost.

Declarative containers still hold mutable state. Plan volumes, backups, upgrades, and ownership. Do not assume rebuilding an image migrates a database safely.

### NixOS VM tests

A NixOS test describes one or more machines and a Python test script:

```nix
pkgs.testers.runNixOSTest {
  name = "nginx-service";

  nodes.server = { ... }: {
    services.nginx.enable = true;
    networking.firewall.allowedTCPPorts = [ 80 ];
  };

  testScript = ''
    server.start()
    server.wait_for_unit("multi-user.target")
    server.wait_for_unit("nginx.service")
    server.wait_for_open_port(80)
    server.succeed("curl --fail http://localhost/")
  '';
}
```

Tests run QEMU VMs through the NixOS test driver. Use `wait_for_unit`, `wait_for_open_port`, `succeed`, `fail`, and multi-node networking to verify behavior, not arbitrary sleeps. Keep tests deterministic and inspect service journals on failure. KVM can accelerate locally but CI may need software emulation.

VM tests validate NixOS integration and runtime behavior for their virtual hardware. They do not prove physical firmware support, performance under production load, or security against all threats.

### Common misconceptions

- **“NixOS containers are VMs.”** They share the host kernel.
- **“Declarative image builds make application state immutable.”** Runtime volumes and databases remain mutable.
- **“Evaluation tests replace VM tests.”** They cannot prove units start or networks function.
- **“A fixed sleep is a reliable readiness check.”** Poll semantic readiness with test-driver helpers.

### Recap

Choose isolation according to kernel-sharing and operational needs. Use NixOS VM tests for deterministic service and network integration, while reserving hardware and production tests for their real environments.

### Exercises

1. Build a private-network NixOS container with one service.
2. Write a two-node VM test for a client and server.
3. Replace test sleeps with readiness checks.
4. Threat-model a namespace container versus a VM.

### Official links

- [NixOS containers](https://nixos.org/manual/nixos/stable/#ch-containers)
- [NixOS tests](https://nixos.org/manual/nixos/stable/#sec-nixos-tests)
- [NixOS test driver](https://nixos.org/manual/nixos/stable/#ssec-machine-objects)
- [Nixpkgs Docker tools](https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-dockerTools)

## Chapter 5: Home Manager

**Platforms:** `[Linux]` `[macOS]` `[NixOS]`

### Objectives

- Choose standalone or NixOS/nix-darwin-integrated Home Manager.
- Manage user packages, dotfiles, and services safely.
- Coordinate state versions and package sets.

### Standalone mode

Standalone Home Manager manages a user profile and home configuration without requiring NixOS:

```nix
{ config, pkgs, ... }:
{
  home.username = "alice";
  home.homeDirectory = "/home/alice";
  home.stateVersion = "24.11";

  home.packages = [ pkgs.ripgrep ];
  programs.git = {
    enable = true;
    userName = "Alice";
  };
}
```

With flakes, expose `homeConfigurations` and activate with:

```console
home-manager switch --flake .#alice@atlas
```

Standalone mode gives users independent updates and activation. The Home Manager CLI and its Nixpkgs input must be coordinated deliberately.

### Integrated mode

The NixOS module integrates home activation into system generations:

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

`useGlobalPkgs` reuses the system package set, avoiding a separate Nixpkgs evaluation and policy mismatch. A separate package set can be intentional when user and system lifecycles differ. nix-darwin has an analogous Home Manager integration module.

Home Manager backs up or refuses conflicting files according to activation configuration; it should not silently overwrite unmanaged content. Review activation output. User services rely on the platform’s user service manager and login/session environment, which differs between Linux and macOS.

`home.stateVersion`, like NixOS `system.stateVersion`, preserves compatibility defaults and should not automatically track package updates.

### Common misconceptions

- **“Home Manager requires NixOS.”** Standalone mode supports other Linux distributions and macOS.
- **“Integrated mode means every user can rebuild the system.”** System activation still follows host privileges.
- **“Home Manager safely stores secrets in dotfiles.”** Generated files may enter the readable Nix store.
- **“State version is the Home Manager release.”** It selects compatibility behavior.

### Recap

Standalone mode favors user autonomy; integrated mode aligns home and system generations. Decide package-set sharing, activation ownership, and state-version policy explicitly.

### Exercises

1. Build a standalone home configuration without activating it.
2. Integrate one home into a NixOS configuration.
3. Compare shared and separate Nixpkgs package sets.
4. Identify files in a home configuration that must not contain plaintext secrets.

### Official links

- [Home Manager manual](https://nix-community.github.io/home-manager/)
- [Home Manager options](https://nix-community.github.io/home-manager/options.xhtml)
- [Home Manager repository](https://github.com/nix-community/home-manager)
- [Home Manager NixOS module](https://nix-community.github.io/home-manager/index.xhtml#sec-install-nixos-module)

## Chapter 6: nix-darwin and Multi-Host Composition

**Platforms:** `[macOS]` `[NixOS]` `[Linux]`

### Objectives

- Understand the boundary between Nix and macOS management.
- Compose heterogeneous hosts without copy-paste or over-generalization.
- Keep host identity and shared policy explicit.

### nix-darwin

nix-darwin applies the Nix module system to macOS configuration. It can manage Nix settings, packages, launchd services, shells, and many macOS defaults:

```nix
darwinConfigurations.orion = darwin.lib.darwinSystem {
  system = "aarch64-darwin";
  specialArgs = { inherit inputs; };
  modules = [
    ./hosts/orion.nix
    home-manager.darwinModules.home-manager
  ];
};
```

Activate through the `darwin-rebuild` workflow documented by the pinned nix-darwin release. nix-darwin is not NixOS for Mac: macOS still owns its kernel, security model, system volume, launchd, software updates, and many settings. Some preference changes require logout, application restart, or are altered by Apple between releases.

Nix-installed shells must also be registered appropriately with macOS. Homebrew interop can be declared with third-party integrations, but Homebrew artifacts do not gain Nix store reproducibility merely because their installation is triggered declaratively.

### Multi-host structure

Compose each host from explicit layers:

```nix
nixosConfigurations = {
  atlas = lib.nixosSystem {
    system = "x86_64-linux";
    modules = [ ./modules/common.nix ./roles/server.nix ./hosts/atlas.nix ];
  };
  ember = lib.nixosSystem {
    system = "aarch64-linux";
    modules = [ ./modules/common.nix ./roles/workstation.nix ./hosts/ember.nix ];
  };
};
```

Good layers include reusable feature modules, policy profiles, roles, hardware modules, and a small host file. Host files should state architecture, boot/storage assumptions, network identity, and role selection. Avoid deriving security-critical identity from a filename or dynamic directory scan when an explicit inventory is clearer.

Use one Nixpkgs pin where compatibility and rollout policy agree. Multiple pins are valid for staged migrations, vendor constraints, or platform support, but document the boundary. Evaluate all hosts, build representative systems on matching builders, and deploy one cohort before broad rollout.

### Common misconceptions

- **“nix-darwin can replace macOS updates and security controls.”** It configures supported surfaces; Apple still owns the operating system.
- **“Every host should use one giant conditional module.”** Explicit role and host composition is easier to reason about.
- **“Sharing one lock guarantees identical systems.”** Architectures, hardware, platform modules, and runtime state differ.
- **“Automatically discovering hosts is always cleaner.”** It can hide inventory changes and evaluation boundaries.

### Recap

nix-darwin brings module-based configuration to macOS without turning it into NixOS. For fleets, compose explicit hosts from reusable roles and policy, document pin boundaries, and roll out by cohort.

### Exercises

1. Draft a nix-darwin host with integrated Home Manager.
2. Refactor two copied host files into common, role, and host layers.
3. Design a staged Nixpkgs upgrade across three host cohorts.
4. List five macOS responsibilities outside nix-darwin’s control.

### Official links

- [nix-darwin manual](https://daiderd.com/nix-darwin/manual/index.html)
- [nix-darwin repository](https://github.com/nix-darwin/nix-darwin)
- [NixOS system configuration](https://nixos.org/manual/nixos/stable/#ch-configuration)
- [Home Manager nix-darwin integration](https://nix-community.github.io/home-manager/index.xhtml#sec-install-nix-darwin-module)
