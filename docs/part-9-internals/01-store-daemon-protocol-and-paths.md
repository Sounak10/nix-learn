# Store, Daemon, Protocol, and Store Paths

## Objectives

By the end of this chapter, you should be able to:

- distinguish the Nix CLI, evaluator, daemon, and store;
- explain why multi-user Nix delegates privileged store operations;
- inspect the store database without editing it;
- describe how input-addressed store paths are derived; and
- separate a store path's identity from the bytes ultimately stored there.

## The layers

A Nix command may parse and evaluate Nix expressions in the client process, then ask a store implementation to realize or query paths. In a typical multi-user installation, the client communicates with `nix-daemon` over a Unix socket. The daemon authenticates the local peer, enforces trust policy, coordinates builds, and mutates the local store.

The daemon protocol is an implementation interface, not a stable application API. It carries version-negotiated operations such as querying valid paths, adding NARs, and building derivations. Prefer the supported CLI or language bindings over writing a protocol client.

The local store usually consists of:

- `/nix/store`: immutable store objects;
- `/nix/var/nix/db`: validity, reference, and derivation metadata;
- `/nix/var/nix/profiles`: profile generations and links; and
- `/nix/var/nix/daemon-socket/socket`: the multi-user daemon socket.

The database is authoritative for which paths are valid and what references they declare. A directory merely existing under `/nix/store` does not make it a valid store object. Never update the SQLite files directly; use Nix store operations.

## Store path derivation

A store path has the form:

```text
/nix/store/<digest>-<name>
```

For classic input-addressed builds, the digest commits to the derivation's build recipe and dependency identities, not simply to the output bytes. Changing a builder, argument, environment variable, dependency path, output name, or relevant platform property can therefore change the output path before the build runs.

Fixed-output derivations are different: their identity includes a promised content hash. This allows Nix to know the destination independently of the process used to fetch or produce the content. Content-addressed store objects generalize the idea, but exact path algorithms are store-method details; do not reproduce them by concatenating strings and hashing.

Names are descriptive but still influence paths. Hash equality across differently named store objects should not be assumed. Use Nix commands to compute or add paths.

## Practical commands

```console
$ nix store info
$ nix store ping
$ nix path-info /run/current-system
$ nix-store --query --hash /nix/store/<hash>-<name>
$ nix-store --query --references /nix/store/<hash>-<name>
$ nix-store --verify --check-contents
```

On systems using the daemon:

```console
$ ps -ax | grep '[n]ix-daemon'
$ nix config show | grep -E '^(store|trusted-users|allowed-users|sandbox) ='
```

Use `nix store info --store daemon` or an explicit store URL when diagnosing which store implementation a command reaches. Command availability and output vary by Nix version; consult `nix help store info`.

## Common misconceptions

- **“The hash is the SHA-256 of the directory.”** Usually false for input-addressed outputs. It represents build identity through Nix's store-path construction.
- **“The daemon evaluates every flake.”** Evaluation commonly happens client-side; store operations may then cross the daemon boundary.
- **“Root owns a store path, so root can safely edit it.”** Mutation violates store assumptions and can corrupt consumers. Rebuild or add a new object.
- **“The database is just a cache.”** Validity and reference metadata are essential to correct realization and garbage collection.
- **“A path in `/nix/store` is automatically trusted.”** Trust involves database validity, cryptographic signatures for substitutes, and daemon policy—not pathname shape.

## Recap

Nix separates evaluation from store operations. The daemon protects and coordinates the shared store, while the store database records validity and references. Classic paths are primarily identities of recipes and inputs; fixed-output and content-addressed objects tie identity more directly to content.

## Exercises

1. Run `nix store info` directly and through the daemon store. Record differences.
2. Choose a store path and compare its references with its recursive closure.
3. Change only a derivation's output name and observe the resulting path.
4. Explain why copying a directory into `/nix/store` manually cannot register it safely.

## Official links

- [Nix store design](https://nix.dev/manual/nix/latest/store/)
- [Nix daemon](https://nix.dev/manual/nix/latest/command-ref/nix-daemon.html)
- [Store path command](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-store.html)
- [Nix database files](https://nix.dev/manual/nix/latest/files/)
