# Content Addressing and Evaluator Performance

## Objectives

By the end of this chapter, you should be able to:

- explain the direction from input-addressed toward content-addressed storage;
- identify why content addressing does not automatically make builds reproducible;
- recognize common evaluator bottlenecks; and
- measure before applying evaluation optimizations.

## The content-addressed direction

Classic Nix derivations are generally input-addressed: output identities follow from recipes and input identities. This gives stable predicted paths, but two independently named recipes that produce identical bytes need not share an output path.

Content-addressed storage derives identity from realized content. It can
improve deduplication, enable early cutoff when rebuilt content is unchanged,
and prevent undetected mutation or path collision once an expected content
address is known. It does not by itself make an untrusted builder's output
correct: a malicious builder can return malicious bytes under their own valid
address. Correctness still requires an independently expected hash, trusted
attestation, or reproducible comparison. Dynamic derivations and
content-addressed derivations are evolving parts of this direction and may
require experimental features in some Nix releases.

Important distinctions:

- **Input-addressed:** identity commits to how an output should be built.
- **Fixed-output:** the derivation promises a known content hash, commonly for fetched sources.
- **Content-addressed:** identity is determined from the realized store object's content and references.

Content addressing verifies sameness of output. It does not ensure that source, compiler, clock, randomness, network responses, or build host were controlled. Reproducibility remains a separate property established by repeated builds and comparison.

## Evaluator performance

Evaluation can consume substantial CPU and memory before any build starts. Frequent causes include:

- repeatedly importing large package sets;
- evaluating broad attribute trees when only a few outputs are needed;
- forcing large lazy values through deep traversal, serialization, tracing, or error formatting;
- generating huge lists with repeated concatenation;
- importing files dynamically and defeating reuse;
- overlay chains that repeatedly recompute package-set fixpoints; and
- unnecessary `builtins.readDir`, `path`, or source filtering over large trees.

Start with observable timing and memory:

```console
$ time nix eval .#packages.x86_64-linux.default.drvPath
$ time nix build .#default --dry-run
$ nix eval --raw nixpkgs#hello.meta.description
$ nix-instantiate --eval --strict expression.nix
```

Compare equivalent expressions one change at a time. `--strict` intentionally forces more of a value and is useful for measurement, but it can make an otherwise lazy workload appear worse.

Practical improvements:

1. Import `nixpkgs` once per relevant system and pass the resulting `pkgs` explicitly.
2. Keep module arguments narrow; avoid passing giant recursively derived values unless needed.
3. Prefer linear list construction (`map`, `concatMap`) over repeated `xs ++ [x]`.
4. Filter source trees deliberately so editor state, VCS metadata, and build outputs do not affect evaluation.
5. Avoid traces in hot paths and remove debugging traces after use.
6. Split evaluation outputs by system and keep flake outputs lazy.

## Common misconceptions

- **“Content-addressed means reproducible.”** It identifies output content; it does not force two builds to produce the same content.
- **“A content hash proves the content is safe.”** It proves identity or integrity relative to that hash.
- **“Nix is lazy, so unused data is free.”** Constructing attrsets and closures still costs memory; consumers may unexpectedly force values.
- **“Build time includes only compilation.”** Evaluation, substitution planning, downloads, and realization are distinct phases.
- **“More overlays are only stylistic.”** Overlay fixpoints can have measurable evaluation cost.

## Recap

Content addressing shifts identity toward realized bytes and references, complementing rather than replacing reproducibility and signatures. Evaluator performance improves most through smaller demanded values, shared imports, linear data transformations, and controlled source inputs.

## Exercises

1. Compare the output paths of two recipes expected to produce identical files and explain the result.
2. Measure evaluation before and after sharing one `nixpkgs` import.
3. Find a source filter boundary in a flake and test whether an ignored file changes its source path.
4. Benchmark repeated list concatenation against `map` for a growing input.

## Official links

- [Content-addressed store objects](https://nix.dev/manual/nix/latest/store/store-object/content-address.html)
- [Experimental features](https://nix.dev/manual/nix/latest/development/experimental-features.html)
- [Nix language constructs](https://nix.dev/manual/nix/latest/language/constructs.html)
- [Nix language built-ins](https://nix.dev/manual/nix/latest/language/builtins.html)
- [Nix performance tips](https://nix.dev/guides/best-practices.html)
