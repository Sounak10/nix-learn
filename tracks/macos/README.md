# Safe macOS evaluation track

This directory is a self-contained nix-darwin and Home Manager example. It is
designed to be evaluated and built, not activated. Nothing in the flake runs
`darwin-rebuild switch`, an activation package, `sudo`, Homebrew, or a host
mutation automatically.

## Safety contract

The configuration intentionally uses placeholders:

- host: `example-mac`
- user: `example`
- platform: `aarch64-darwin`

Do **not** activate it unchanged. The placeholder account probably does not
exist, and the example has not been reviewed for your machine. Evaluation and
building create Nix store objects; activation changes the host.

Safe, non-activating commands:

```console
cd tracks/macos
nix flake metadata --no-write-lock-file
nix flake show --no-write-lock-file
nix eval --no-write-lock-file \
  .#darwinConfigurations.example-mac.config.networking.hostName
nix eval --no-write-lock-file \
  .#darwinConfigurations.example-mac.config.system.stateVersion
nix eval --no-write-lock-file \
  '.#homeConfigurations."example@example-mac".config.home.stateVersion'
nix build --no-write-lock-file \
  .#darwinConfigurations.example-mac.system
nix build --no-write-lock-file \
  '.#homeConfigurations."example@example-mac".activationPackage'
nix flake check --no-write-lock-file
```

`nix build` and `nix flake check` may download and compile dependencies and
write store paths, but they do not activate the resulting host or home
configuration. Do not execute `./result/activate`.

The following are intentionally **not** safety checks:

```console
sudo darwin-rebuild switch --flake .#example-mac
./result/activate
```

They activate configurations and mutate the host or home directory.

## Inputs

The three direct sources are exact Git revisions current when this example was
written:

- Nixpkgs `a32edd7654519351e48e80372a928df336394670`
- Home Manager `d2a22a3659a6ae99847ea9176114f6957b8ac62e`
- nix-darwin `4cff07de74b50e64bdd68cd4e722ab5b6b35ee48`

Home Manager and nix-darwin both follow the same Nixpkgs input. Exact revision
URLs make the direct inputs immutable without relying on a generated lock
file. On a machine with Nix, you may additionally generate and commit
`flake.lock`:

```console
nix flake lock
nix flake metadata
```

Review the lock diff before committing it. An update should change the
revision URLs deliberately, regenerate the lock if used, read both projects'
release notes, and build before any activation.

## Layout and outputs

- `flake.nix` pins inputs and exports the configurations and build-only checks.
- `configuration.nix` is the nix-darwin host module.
- `home.nix` is reused by integrated and standalone Home Manager.

Available outputs:

```text
darwinConfigurations.example-mac
homeConfigurations."example@example-mac"
checks.aarch64-darwin.darwin-system
checks.aarch64-darwin.home-activation
```

The nix-darwin output integrates Home Manager. The standalone output
demonstrates the independent Home Manager lifecycle without requiring a
system switch. Never activate both against the same real account unless you
have explicitly designed ownership to avoid profile and file conflicts.

## Adapting for a real Mac

Make a separate copy or commit before adaptation, then:

1. choose `aarch64-darwin` for Apple Silicon or `x86_64-darwin` for Intel;
2. replace `example-mac` with the intended `LocalHostName`;
3. replace `example` and `/Users/example` with an existing account and home;
4. inspect every package, generated file, shell setting, and module option;
5. keep `system.stateVersion` and `home.stateVersion` at their initial values;
6. build both outputs without activation;
7. retain a known-good nix-darwin generation and current source revision;
8. back up mutable data; and
9. activate only through a deliberate administrator command.

Changing a state version is a migration, not a routine update. Read the
release notes and changelog before changing either value.

## Failure and recovery

For an evaluation error:

```console
nix build --no-write-lock-file \
  .#darwinConfigurations.example-mac.system --show-trace
```

Check the output name, host platform, exact input revisions, and first useful
module assertion. Because Nix is not available in every documentation
environment, the exact pins should also be evaluated on a macOS machine with
the multi-user Nix daemon before use.

If a separately adapted configuration was activated and failed:

```console
sudo darwin-rebuild --list-generations
sudo darwin-rebuild --rollback
```

Rollback restores a retained nix-darwin generation, not Git source, Homebrew
state, application databases, or macOS settings outside that generation.
Restore mutable data from backups when needed, fix the source, and rebuild.

## Official references

- [nix-darwin manual](https://nix-darwin.github.io/nix-darwin/manual/)
- [nix-darwin repository](https://github.com/nix-darwin/nix-darwin)
- [Home Manager manual](https://nix-community.github.io/home-manager/)
- [Home Manager options](https://nix-community.github.io/home-manager/options.xhtml)
- [Nix flake commands](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake)
