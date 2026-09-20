# Security, Sandboxing, Policy, and Anti-patterns

## Objectives

By the end of this chapter, you should be able to:

- describe a practical Nix threat model;
- state what build sandboxing does and does not guarantee;
- handle unfree, insecure, and secret-bearing inputs deliberately;
- recognize dangerous operational anti-patterns; and
- plan a channels-to-flakes migration without breaking rollback.

## Threat model

Consider at least these actors and assets:

- untrusted package source attempting to affect the host during evaluation or build;
- compromised binary cache serving malicious outputs;
- untrusted local user interacting with a privileged daemon;
- compromised remote builder returning poisoned results;
- accidental disclosure through derivations, logs, store paths, caches, or flake inputs; and
- vulnerable or policy-restricted software deliberately selected by configuration.

Nix improves isolation and integrity, but it is not a malware scanner, vulnerability manager, or complete privilege boundary. Review who may configure the daemon, which keys are trusted, what builders can access, and where outputs are published.

## Sandbox caveats

Build sandboxing restricts filesystem and, on supported platforms and configurations, network access. Its strength varies by operating system, Nix version, daemon mode, and options. Fixed-output fetchers may receive network access because their output is checked against an expected hash. Tests requiring kernel features, virtualization, or unusual devices may need declared system features or carefully scoped exceptions.

```console
$ nix config show | grep -E '^(sandbox|sandbox-paths|extra-sandbox-paths|trusted-users) ='
$ nix build .#package --option sandbox true
```

Do not assume sandboxing:

- protects against malicious code after installation or execution;
- makes an impure derivation reproducible;
- hides environment values already embedded in a derivation;
- provides identical guarantees on Linux and macOS; or
- safely permits arbitrary users to become `trusted-users`.

## Unfree and insecure packages

“Unfree” is a licensing classification. “Insecure” is a package policy marker for known or unacceptable security status. They are not interchangeable and should not be enabled globally without review.

For Nixpkgs, prefer narrow predicates:

```nix
{
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkg.pname or (lib.getName pkg)) [ "approved-tool" ];

  nixpkgs.config.permittedInsecurePackages = [
    "legacy-service-1.2.3"
  ];
}
```

Pin exceptions to exact names or versions where practical, record an owner and expiry, and test removal regularly. Configuration placement differs between NixOS modules, direct Nixpkgs imports, and flake evaluations.

## Secrets are not hidden by the store

The Nix store is globally readable on many installations, copied between machines, retained by roots, indexed by caches, and exposed through derivations and logs. Never interpolate a secret into:

- a Nix string that contributes to a derivation;
- `environment`, builder arguments, generated configuration, or source files;
- a flake input URL containing credentials; or
- a command that may be logged.

Use runtime secret provisioning: systemd credentials, a dedicated secret manager, protected files outside the store, or deployment-time decryption into a restricted runtime directory. Refer to a secret's runtime path, not its value. Even “encrypted secrets in the store” disclose metadata and depend on correct key handling.

## Anti-patterns

Avoid:

- `curl ... | sh` inside builds or undeclared network access;
- placing API tokens in `nix.conf`, flake URLs, derivation environment, or generated store files;
- making every local user trusted to bypass configuration errors;
- editing `/nix/store` or its database manually;
- globally disabling sandboxing or signature requirements;
- using `--impure` as a permanent dependency-injection mechanism;
- following an unpinned moving branch in production;
- huge overlays for values that plain functions or modules can pass explicitly;
- copying only a top-level output rather than its closure; and
- treating garbage collection as a substitute for retention policy and backups.

## Migrating from channels to flakes

Migrate incrementally:

1. Inventory channels, `<nixpkgs>` imports, `NIX_PATH`, overlays, and imperative profile installs.
2. Capture the current revision and preserve a rollback generation.
3. Create a flake input pinned by `flake.lock`.
4. Convert one output at a time while keeping system architecture explicit.
5. Move package configuration and overlays into deliberate flake inputs or modules.
6. Compare closures and service behavior before switching.
7. Commit the lock file and define an update cadence.
8. Remove channel and `NIX_PATH` dependencies only after searches and clean-environment tests pass.

```console
$ nix-channel --list
$ nix flake lock
$ nix flake check
$ nix build .#checks.x86_64-linux.default
$ nix store diff-closures ./old-result ./new-result
```

Flakes improve input pinning and output conventions; they do not automatically make builds pure, secure, or reproducible.

## Common misconceptions

- **“Sandboxed means safe to run.”** The sandbox concerns the build phase, not runtime behavior.
- **“Unfree means vulnerable.”** Licensing and security policy are separate.
- **“A store path is obscure enough for a secret.”** Store data and metadata are commonly readable and copied.
- **“Flakes replace the Nix language.”** Flakes structure and lock inputs; package and module logic still uses Nix.
- **“A lock file should never change.”** It should change through reviewed, tested updates.

## Recap

Secure Nix operations combine sandboxing, least-privilege daemon policy, trusted cache keys, controlled builders, runtime secret injection, explicit package exceptions, and pinned inputs. Flake migration should preserve rollback and compare resulting closures.

## Exercises

1. Write a threat model for one workstation and one CI builder.
2. Search a sample derivation JSON for a fake token and explain every disclosure route.
3. Replace a global unfree allowance with a named predicate.
4. Draft a staged channel-to-flake migration including rollback and acceptance checks.

## Official links

- [Nix sandbox configuration](https://nix.dev/manual/nix/latest/command-ref/conf-file.html#conf-sandbox)
- [Nix security](https://nix.dev/manual/nix/latest/installation/multi-user.html)
- [Nixpkgs licensing](https://nixos.org/manual/nixpkgs/stable/#sec-allow-unfree)
- [Nixpkgs insecure packages](https://nixos.org/manual/nixpkgs/stable/#sec-installing-insecure-packages)
- [Flakes](https://nix.dev/concepts/flakes.html)
- [Pinning Nixpkgs](https://nix.dev/guides/recipes/dependency-management.html)
