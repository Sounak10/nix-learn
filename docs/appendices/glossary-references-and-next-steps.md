# Glossary, Official References, and Next Steps

## Objectives

Use this appendix to normalize terminology, locate primary documentation, and choose a practical next project after learning Nix internals.

## Glossary

**Builder**  
The executable named by a derivation, or informally a machine that executes builds. Use “remote builder” for the machine to avoid ambiguity.

**Closure**  
A store path plus every store path transitively reachable through registered references.

**Content address**  
An identity derived from content, including the serialization method and, where relevant, references.

**Derivation**  
A low-level build plan describing builder, arguments, environment, inputs, platform, and outputs. Its store representation commonly ends in `.drv`.

**Evaluation**  
Execution of Nix language expressions to produce values, often including derivations. Evaluation is distinct from building.

**Fixed-output derivation**  
A derivation whose output is constrained by a declared content hash, often used for downloads.

**Flake**  
A convention and command interface for locked inputs and schema-like outputs. A flake is not a replacement for the Nix language.

**Garbage-collection root**  
A registered starting point whose reachable store closure must remain alive.

**Input-addressed derivation**  
A derivation whose output identity is based primarily on build recipe and input identities rather than realized output content.

**Import from derivation (IFD)**  
Evaluation that realizes a derivation and then imports generated Nix code. IFD
crosses the evaluation/build boundary and can harm evaluation purity,
parallelism, and availability.

**Home Manager**  
A module-system application that builds and activates declarative user
environments on NixOS, other Linux distributions, and macOS.

**NAR**  
Nix Archive: the canonical serialization used to hash and transfer filesystem objects.

**NARInfo**  
Binary-cache metadata connecting a store path to a NAR URL, hashes, sizes, references, deriver, and signatures.

**nix-darwin**  
A module-system application for supported macOS configuration surfaces. It
does not replace the macOS kernel, security model, updater, or launchd.

**Output**  
One result of a derivation, such as `out`, `dev`, `lib`, or `doc`.

**Realization**  
Producing or obtaining valid derivation outputs, either by building or substitution.

**Reference**  
A registered edge from one store object to another. References determine closures and garbage-collection reachability.

**Store**  
The abstraction that holds immutable objects and validity/reference metadata. `/nix/store` is the usual local filesystem store.

**Store path**  
An identifier such as `/nix/store/<digest>-<name>`.

**Substitute**  
A prebuilt store object used instead of executing its derivation.

**Substituter / binary cache**  
A store endpoint from which Nix queries and downloads substitutes.

**System**  
A Nix platform identifier such as `x86_64-linux` or `aarch64-darwin`. It is more specific than CPU architecture alone.

**Trusted user**  
A user granted elevated authority by the Nix daemon. This is a security-sensitive role, not merely permission to build.

## Curated official references

Start with task-oriented material:

- [nix.dev tutorials](https://nix.dev/tutorials/)
- [nix.dev guides](https://nix.dev/guides/)
- [Nix language basics](https://nix.dev/tutorials/nix-language.html)
- [Packaging existing software](https://nix.dev/tutorials/packaging-existing-software.html)

Use the manuals for precise behavior:

- [Nix manual](https://nix.dev/manual/nix/latest/)
- [Nix command reference](https://nix.dev/manual/nix/latest/command-ref/)
- [Nix language reference](https://nix.dev/manual/nix/latest/language/)
- [Nix store reference](https://nix.dev/manual/nix/latest/store/)
- [Nixpkgs manual](https://nixos.org/manual/nixpkgs/stable/)
- [NixOS manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager manual](https://nix-community.github.io/home-manager/)
- [nix-darwin manual](https://nix-darwin.github.io/nix-darwin/manual/)
- [sops-nix](https://github.com/Mic92/sops-nix)
- [agenix](https://github.com/ryantm/agenix)
- [deploy-rs](https://github.com/serokell/deploy-rs)
- [Colmena](https://colmena.cli.rs/)

Follow project sources when behavior is version-sensitive:

- [Nix releases](https://github.com/NixOS/nix/releases)
- [Nix source](https://github.com/NixOS/nix)
- [Nixpkgs source](https://github.com/NixOS/nixpkgs)
- [NixOS Security Team](https://nixos.org/community/teams/security/)
- [NixOS RFCs](https://github.com/NixOS/rfcs)

Prefer the manual matching the deployed Nix version. The `latest` manual can document behavior or defaults absent from older production systems.

## Next steps

### 1. Build an inspection notebook

Choose one package and record:

```console
$ nix derivation show nixpkgs#hello
$ nix path-info --json --recursive --closure-size nixpkgs#hello
$ nix why-depends nixpkgs#hello nixpkgs#glibc
```

Explain build inputs, runtime references, closure size, and substitution source.

### 2. Operate a disposable binary cache

Create a local `file://` cache, copy a closure, inspect its `.narinfo`, verify it, and delete the experiment. Do not begin with a public or production cache.

### 3. Add a remote builder

Use a disposable VM, a dedicated SSH key, restricted accounts, explicit system features, and no production signing key. Prove dispatch with local jobs disabled, then test fallback.

### 4. Reproducibility experiment

Build the same derivation independently on two compatible machines, compare NAR hashes, and investigate differences without assuming that equal input-addressed paths imply equal bytes.

### 5. Migrate one channel-based project

Pin Nixpkgs with a flake, preserve the previous generation, compare closures, document lock updates, and remove `NIX_PATH` dependence only after a clean-environment test.

### 6. Write an operational policy

Define trusted users, approved substituters and keys, builder access, unfree/insecure exception review, secret provisioning, garbage-collection retention, and incident response.

## Common misconceptions

- Secondary blog posts are not authoritative for current command behavior.
- The newest manual may not match an older daemon.
- Completing a tutorial does not validate production trust policy.
- Reproducibility, integrity, provenance, and licensing are separate review dimensions.

## Recap

Use precise graph and store terminology, consult version-matched official manuals, and reinforce internals through small disposable operations before changing shared infrastructure.

## Exercises

1. Define “derivation,” “realization,” “substitute,” and “closure” without using “package.”
2. Find the manual corresponding to the Nix daemon on your machine.
3. Select one next-step project and write success, rollback, and security criteria.

## Official links

- [Nix ecosystem overview](https://nix.dev/)
- [Nix manual](https://nix.dev/manual/nix/latest/)
- [Nixpkgs manual](https://nixos.org/manual/nixpkgs/stable/)
- [NixOS manual](https://nixos.org/manual/nixos/stable/)
