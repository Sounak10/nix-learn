# 10. Reproducibility in Practice

## Objectives

By the end of this chapter, you will be able to:

- define reproducibility at evaluation, build, and deployment boundaries;
- identify common sources of nondeterminism;
- test builds through rebuilding and closure inspection;
- state what Nix guarantees and where additional controls are required.

## Reproducibility Is a Layered Claim

“This is reproducible” is incomplete unless it names the boundary. Useful claims include:

1. **Reproducible evaluation**: the same pinned inputs select the same derivation graph.
2. **Reproducible environment**: users receive the same store paths and environment composition.
3. **Bit-reproducible build**: independent realizations produce byte-identical canonical outputs.
4. **Behavioral reproducibility**: the program behaves equivalently under stated runtime conditions.
5. **Deployability**: the complete runtime closure can be transferred and executed on a compatible target.

Nix provides strong machinery for the first two and for closure deployment. It makes bit reproducibility testable and often achievable, but does not force arbitrary builders to be deterministic. Behavioral equivalence also depends on kernels, CPUs, external services, data, time, and configuration.

## Pin Every Moving Input

Unpinned registry names, channels, branches, and mutable URLs can resolve differently later. A project should record immutable revisions and content hashes. A flake lock file is one modern pinning mechanism, though this book deliberately does not create a flake.

Even with pinned Nix code, fetched content must be immutable or hash-verified. The effective Nix version, enabled experimental features, platform, and evaluator behavior may also matter. Long-lived projects should record supported Nix versions and update intentionally.

Inspect metadata for an installable:

```console
# nix flake metadata nixpkgs
# nix path-info --derivation nixpkgs#hello
```

The registry's `nixpkgs` target may move. The command is useful for exploration, not proof of a project pin.

## Sources of Build Nondeterminism

Common causes include:

- timestamps and current dates embedded in archives or binaries;
- random seeds, temporary names, and nondeterministic iteration order;
- parallel race conditions;
- locale, timezone, or character-encoding differences;
- absolute build-directory paths;
- filesystem directory ordering;
- CPU-specific code generation and feature detection;
- network responses or mutable remote resources;
- undeclared host tools and configuration;
- signatures whose format intentionally includes randomness;
- test suites that depend on timing or external services.

Mitigations include `SOURCE_DATE_EPOCH`, deterministic archive flags, stable sorting, fixed locale/timezone, remapped debug paths, controlled parallelism, and upstream reproducible-build patches. The exact fix belongs in the builder or build system, not in Nix syntax alone.

## Rebuild to Test

`nix build` normally reuses an existing valid output, so it does not independently test reproducibility. Request a rebuild and compare:

```console
# nix build nixpkgs#hello --no-link
# nix build nixpkgs#hello --rebuild --no-link
```

Nix may report a mismatch if a rebuilt result differs from an existing valid path, depending on addressing mode and configuration. Strong testing rebuilds on independent machines or builders and compares canonical NAR contents.

Hash a realized path:

```console
# p=$(nix path-info nixpkgs#hello)
# nix hash path "$p"
```

This gives evidence about the current canonical tree. Matching one cache copy does not demonstrate that independent source builds converge.

## Verify Store Integrity

Verify registered content:

```console
# nix store verify --all
```

Verification checks store metadata, hashes where available, and optionally signatures according to flags and configuration. It detects corruption or missing trust evidence; it is not a fresh source rebuild.

Repairing or re-downloading paths is a separate operation and may require network access, trusted substituters, and permissions.

## Inspect the Runtime Closure

A deployable result includes its closure:

```console
# nix path-info --recursive nixpkgs#hello
# nix path-info --closure-size nixpkgs#hello
```

Inspect unexplained size or dependencies:

```console
# nix why-depends nixpkgs#hello nixpkgs#glibc
```

The exact dependency exists only on systems where that package uses glibc; on macOS, choose a reported closure member instead:

```console
$ nix path-info --recursive nixpkgs#hello
$ nix why-depends nixpkgs#hello /nix/store/<chosen-path>
```

Unwanted references can leak build tools, secrets embedded as files, or unnecessary libraries into deployment. Nix tracks exact store-path references, but it does not classify every dependency as desirable.

## Platform and Runtime Limits

A derivation's `system` identifies a Nix platform such as `x86_64-linux` or `aarch64-darwin`. Matching that string does not make machines physically identical. Builders and binaries can observe:

- kernel and syscall behavior;
- CPU features and microcode;
- resource limits;
- filesystems and case sensitivity;
- emulation;
- sandbox implementation;
- runtime devices, network, and secrets.

Cross-compilation distinguishes build, host, and target platforms at higher levels such as Nixpkgs. A package that builds on one platform is not automatically portable to another.

## Secrets and Purity

Never place secrets directly in Nix expressions, derivation attributes, command-line arguments, or source trees copied into the store. Store objects and `.drv` files are commonly readable by local users and may be uploaded to caches.

Runtime secret injection should occur outside immutable public store content. If a build truly requires private material, use purpose-built secret handling and prevent cache publication; recognize that this weakens independent reproducibility.

Pure evaluation prevents some ambient reads. Sandboxing prevents some build-time reads. Neither redacts a secret you explicitly pass.

## A Practical Review Checklist

Before claiming a build is reproducible, ask:

- Are source and dependency revisions immutable and pinned?
- Are fetches hash-verified?
- Does evaluation avoid ambient environment and host paths?
- Does the builder run sandboxed with declared tools?
- Are timestamps, randomness, locale, ordering, and paths normalized?
- Have independent rebuilds produced equal canonical output?
- Is the expected runtime closure understood and transferable?
- Are cache keys and signatures governed by an explicit trust policy?
- Are platform assumptions and supported Nix versions recorded?
- Are secrets absent from expressions, derivations, logs, outputs, and caches?

## Common Misconceptions

- **“Same store path proves independent builds had equal bytes.”** Not for every input-addressed build.
- **“Pinned Nixpkgs pins every runtime input.”** External data, services, platform behavior, and improperly fetched sources can remain variable.
- **“`nix store verify` rebuilds from source.”** It verifies existing store objects.
- **“A sandbox eliminates nondeterminism.”** It reduces undeclared host inputs but cannot normalize time, randomness, or races automatically.
- **“A complete closure runs anywhere.”** The target must be platform-compatible and provide required runtime facilities.
- **“Purity keeps secrets safe.”** Explicitly supplied secrets can still leak into world-readable store metadata or outputs.

## Recap

Nix makes dependency identity, immutable results, substitution, and closure deployment explicit. Reproducibility still requires pinned inputs, deterministic builders, compatible platforms, independent rebuild evidence, integrity checks, and deliberate cache and secret policies.

## Exercises

1. List five nondeterminism sources for a build system you know and propose one mitigation for each.
2. Build `hello`, hash its path, request `--rebuild`, and hash it again.
3. Verify your store or a selected path and explain why this is not a source rebuild.
4. Inspect `hello`'s closure and use `nix why-depends` for one dependency.
5. Write a precise reproducibility claim that names inputs, Nix version range, platform, and whether byte identity was independently tested.

## Official Sources

- [Reproducible builds with Nix](https://nix.dev/guides/reproducible-builds)
- [`nix store verify`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-store-verify)
- [`nix why-depends`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-why-depends)
- [Nix platforms](https://nix.dev/manual/nix/latest/system-types)
- [Nix security](https://nix.dev/manual/nix/latest/installation/nix-security)
- [Reproducible Builds project](https://reproducible-builds.org/docs/)
