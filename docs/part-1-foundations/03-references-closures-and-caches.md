# 3. References, Closures, and Binary Caches

## Objectives

By the end of this chapter, you will be able to:

- explain store references and runtime closures;
- inspect dependency graphs and closure sizes;
- describe substitution, substituters, signatures, and trust;
- distinguish source availability from binary-cache availability.

## References Form a Graph

A store object can contain the exact textual path of another store object. Nix records that occurrence as a **reference**. If executable `A` refers to library `B`, `B` must remain available whenever `A` is used.

The **closure** of a path is the path itself plus every path reachable by repeatedly following references. This graph is central to deployment, copying, cache downloads, and garbage collection.

Inspect direct and recursive references:

```console
# nix path-info nixpkgs#hello
/nix/store/...-hello-...
# p=$(nix path-info nixpkgs#hello)
# nix-store --query --references "$p"
# nix-store --query --requisites "$p"
```

The legacy query command remains useful for graph inspection. Modern alternatives can show JSON and closure size:

```console
# nix path-info --json --closure-size nixpkgs#hello
# nix-store --query --graph "$(nix path-info nixpkgs#hello)" \
    > /tmp/hello.dot
```

Use Graphviz, when available, to render the DOT graph:

```console
# nix shell nixpkgs#graphviz --command \
    dot -Tsvg /tmp/hello.dot -o /tmp/hello.svg
```

## Build-Time Inputs Versus Runtime References

A compiler can be required to build a program without being referenced by the final executable. Conversely, a wrapper script may embed the path of a runtime tool. Therefore:

- the derivation's input graph describes what is needed to build;
- the output's reference graph describes what must accompany the result.

They overlap, but they are not identical. This is why closure size is a better deployment measure than output directory size.

Reference scanning is path based. Merely storing a full `/nix/store/...` string in generated documentation may retain that target in the closure. Build tooling often removes references or splits outputs to keep closures small.

## Substitution Instead of Local Building

Before building, Nix asks configured **substituters**—usually binary caches—whether they already have the required store path. If one does, Nix downloads a NAR archive plus metadata instead of running the builder. This is called **substitution**.

Inspect configuration:

```console
# nix config show substituters
# nix config show trusted-public-keys
```

The default public cache is commonly `https://cache.nixos.org/`. A cache result is useful only when:

1. evaluation requests the same store path;
2. the substituter has that path;
3. trust and signature policy permit it;
4. platform and feature requirements match.

Try a dry run:

```console
# nix build --dry-run nixpkgs#hello
```

Copy a closure between stores or caches:

```console
# nix copy --to file:///tmp/my-cache nixpkgs#hello
# nix path-info --store file:///tmp/my-cache --all
```

The local file cache above is useful for learning. Production caches require deliberate signing, access control, retention, and availability policies.

## Signatures and Trust

Input-addressed paths identify the expected build recipe, but a malicious server could still claim arbitrary bytes for that path. Signed cache metadata lets Nix verify that a trusted cache vouches for the object.

Do not add unknown public keys or mark arbitrary users as trusted merely to silence an error. In daemon installations, `trusted-users` can grant capabilities close to root-level control over the Nix store.

Content hashes, signatures, and transport security answer different questions:

- a hash detects content mismatch;
- a signature associates metadata with a trusted signer;
- TLS protects communication with an endpoint.

## Copying Closures

Because references are explicit, Nix can copy complete closures:

```console
# nix copy --to file:///tmp/export-cache nixpkgs#hello
# rm -rf /tmp/empty-store
# nix path-info --store file:///tmp/export-cache --recursive \
    "$(nix path-info nixpkgs#hello)"
```

Copying a root path normally includes dependencies required by its closure. It does not imply that build-time-only dependencies are included unless they remain referenced or you explicitly copy the derivation closure.

## Common Misconceptions

- **“Dependencies are whatever appears in `PATH`.”** Store references are recorded edges between exact paths.
- **“All build inputs ship at runtime.”** Only referenced runtime closure members must accompany an output.
- **“A binary cache is a source-code mirror.”** It serves store objects and metadata; source objects may be among them but are not the whole model.
- **“Same package name means a cache hit.”** The exact requested store path must match.
- **“TLS makes cache signatures unnecessary.”** They protect different boundaries.

## Recap

References turn store objects into a directed graph; closures are reachable subgraphs. Nix moves and retains closures as units. Substituters avoid repeated builds by serving exact store objects whose metadata satisfies local trust policy.

## Exercises

1. Compare direct references and recursive requisites of `nixpkgs#hello`.
2. Find the output's own disk size and its closure size.
3. Create a local file cache and copy `hello` into it.
4. Explain why a compiler may be absent from a program's runtime closure.
5. List the configured substituters and trusted public keys in your environment.

## Official Sources

- [Store object references](https://nix.dev/manual/nix/latest/store/store-object)
- [Nix store closure](https://nix.dev/manual/nix/latest/store/store-path)
- [`nix copy`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-copy)
- [Serving a binary cache](https://nix.dev/manual/nix/latest/package-management/binary-cache-substituter)
- [Nix configuration reference](https://nix.dev/manual/nix/latest/command-ref/conf-file)
