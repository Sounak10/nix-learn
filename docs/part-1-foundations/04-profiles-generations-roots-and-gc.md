# 4. Profiles, Generations, Roots, and Garbage Collection

## Objectives

By the end of this chapter, you will be able to:

- distinguish store presence from profile installation;
- inspect and roll back profile generations;
- identify direct and indirect garbage-collection roots;
- collect unreachable store objects safely.

## Profiles Point to Selected Packages

A **profile** is a mutable user-facing reference to an immutable environment in the store. Updating it creates a new **generation** and moves the profile symlink; it does not alter old outputs.

In a disposable container:

```console
# nix profile list
# nix profile add nixpkgs#hello
# nix profile list
# hello
Hello, world!
```

The default per-user profile exposes package binaries through shell initialization. A `nix shell` environment, by contrast, is temporary and does not create a profile generation.

Modern profile operations include:

```console
# nix profile list
# nix profile history
# nix profile upgrade --all
# nix profile remove hello
```

Profile element identifiers shown by `nix profile list` are the reliable operands for remove or upgrade; do not assume the package's display name is always the identifier.

## Generations Enable Rollback

Each transactional change can create a generation:

```console
# nix profile history
# nix profile rollback
# nix profile history
```

Rollback switches the profile to an earlier immutable environment. It cannot restore paths already garbage-collected after their roots were removed. Old generation links ordinarily act as roots until deleted.

Delete old generations deliberately:

```console
# nix profile wipe-history --older-than 30d
```

In a short-lived Docker container, dates and persistent history are less instructive than on a native installation. Do not copy retention commands into production without deciding how many rollback points you need.

## Roots Keep Store Paths Alive

Garbage collection starts from **GC roots**, follows all references, and deletes store paths not reachable from any root.

Typical roots include:

- profile generation symlinks;
- system generations on NixOS;
- `result` symlinks created by `nix build`;
- roots registered by running processes or temporary build activity;
- indirect roots tracked under Nix's GC-root directory.

Build a package and inspect its root:

```console
# mkdir -p /tmp/gc-demo && cd /tmp/gc-demo
# nix build nixpkgs#hello
# ls -l result
# nix-store --query --roots "$(readlink -f result)"
```

The root itself is not necessarily inside `/nix/store`; it points into the store. Its target and target closure become live.

## Garbage Collection

Preview unreachable paths:

```console
# nix store gc --dry-run
```

Delete unreachable objects:

```console
# nix store gc
```

Removing a `result` symlink only removes one root:

```console
# rm result
# nix store gc --dry-run
```

The output may remain because a profile, another output, or a running process still reaches it. Conversely, a source path or expensive local build with no root can be collected.

## Optimisation Is Not Collection

Store optimisation hard-links identical regular files to save disk space:

```console
# nix store optimise
```

It does not decide reachability or remove packages. Garbage collection and optimisation solve different problems. Filesystem compression and cache retention are separate again.

## Profiles Are Not Dependency Locks

A profile records concrete installed elements and generations, but it is not the best source-controlled project specification. Project inputs should be declared and pinned in project configuration. Profiles are convenient state for humans and machines, not a substitute for dependency declarations.

Likewise, a package being present in the store does not mean it is installed into a profile. Store presence means only that some operation fetched, built, or retained it.

## Common Misconceptions

- **“Uninstall deletes package files immediately.”** It removes a profile reference; collection happens later if nothing else reaches the paths.
- **“Every store path is permanent.”** Unreachable paths are collectible.
- **“Rollback rebuilds the old package.”** It normally repoints to an old generation whose closure is still present.
- **“Deleting `result` deletes the output.”** It only removes that root.
- **“`nix store optimise` is GC.”** It deduplicates identical files rather than determining liveness.

## Recap

Profiles present chosen store paths, and generations make profile changes transactional and reversible. Roots define liveness. Garbage collection deletes paths outside every rooted closure, while store optimisation deduplicates files.

## Exercises

1. Install two small packages into a profile and inspect its history.
2. Remove one profile element, roll back, and verify that its command returns.
3. Build a package with a `result` link, query its roots, remove the link, and dry-run GC.
4. Explain why a store path can survive after profile removal.
5. Compare the purpose of `nix store gc` and `nix store optimise`.

## Official Sources

- [`nix profile`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-profile)
- [`nix profile history`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-profile-history)
- [Garbage collection](https://nix.dev/manual/nix/latest/package-management/garbage-collection)
- [`nix store gc`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-store-gc)
- [`nix store optimise`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-store-optimise)
