# Derivations, Graphs, and Closure Copying

## Objectives

By the end of this chapter, you should be able to:

- read the important parts of a derivation;
- distinguish derivation inputs, output references, and runtime closures;
- inspect dependency graphs and explain garbage-collection roots; and
- copy complete closures between stores.

## Derivations are build plans

A derivation is a low-level build plan containing a builder, arguments, environment, target platform, declared outputs, source inputs, and dependencies on other derivations. Evaluation produces derivations; realization executes the required build graph and registers valid outputs.

Two related graphs matter:

1. **Build-time graph:** derivations and source paths needed to build an output.
2. **Runtime reference graph:** store paths found or declared in realized outputs.

They overlap, but are not identical. A compiler can be required to build a program without appearing in its runtime closure. Conversely, a path embedded in an output becomes a runtime reference even when that reference was accidental.

The **closure** of a path is the path plus all paths reachable through registered references. Copying only the top-level directory creates an incomplete deployment. Garbage collection also follows this graph starting at roots such as profiles, current-system links, and explicit roots.

## Inspecting the graph

```console
$ nix derivation show nixpkgs#hello
$ nix path-info --derivation nixpkgs#hello
$ nix path-info --recursive --size --closure-size nixpkgs#hello
$ nix-store --query --references "$(nix build --no-link --print-out-paths nixpkgs#hello)"
$ nix-store --query --referrers /nix/store/<hash>-<name>
$ nix-store --query --tree /nix/store/<hash>-<name>
```

`nix derivation show` exposes low-level details. Treat its JSON as diagnostic data rather than a hand-authored configuration format. Secrets passed in derivation environment variables or arguments can become visible here.

## Copying closures

Copy with the modern store command:

```console
$ nix copy --to ssh-ng://builder.example nixpkgs#hello
$ nix copy --from https://cache.nixos.org /nix/store/<hash>-<name>
$ nix copy --to file:///tmp/nix-export /nix/store/<hash>-<name>
```

Nix computes and transfers missing closure members. The destination verifies hashes and, depending on store and trust configuration, signatures. `nix-copy-closure` remains useful on older systems:

```console
$ nix-copy-closure --to builder.example /nix/store/<hash>-<name>
```

For deployment, copy the realized runtime closure. For delegated building, the remote store also needs the derivation and its build-time inputs; the build machinery arranges this.

## Common misconceptions

- **“A derivation is a package.”** It is a build action; one package may involve several derivations and outputs.
- **“The dependency graph is one graph.”** Build dependencies and runtime references answer different questions.
- **“Copying the output directory is enough.”** Binaries often reference interpreters, libraries, locale data, or wrappers elsewhere in the store.
- **“Every textual store path becomes a reference.”** Reference scanning and registration depend on the object and build mechanism; inspect registered references.
- **“A garbage-collection root copies data.”** A root keeps reachable data alive; it is generally a link or registration, not a duplicate.

## Recap

Evaluation constructs a derivation graph, realization executes it, and realized outputs form a reference graph. Closures are the transitive units for copying, deployment, and garbage collection.

## Exercises

1. Build `nixpkgs#hello`, inspect its derivation, and classify each input as build-time or runtime.
2. Compare `--size` and `--closure-size` for a package with many dependencies.
3. Copy a closure to a local `file://` store and verify it there.
4. Create a temporary GC root with `nix build --out-link`, then reason about what survives collection.

## Official links

- [Derivations](https://nix.dev/manual/nix/latest/language/derivations.html)
- [Store object closure](https://nix.dev/manual/nix/latest/store/store-object.html)
- [`nix derivation show`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-derivation-show.html)
- [`nix copy`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-copy.html)
- [Garbage collection](https://nix.dev/manual/nix/latest/package-management/garbage-collection.html)
