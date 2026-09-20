# Troubleshooting Decision Trees

## Objectives

Use this appendix to classify a failure quickly, gather the smallest useful evidence set, and choose a command that tests one hypothesis at a time.

## Tree 1: `nix build` failed

```text
Did evaluation produce a derivation?
├─ No
│  ├─ Syntax/undefined variable → nix eval --show-trace
│  ├─ Missing or dirty flake input → nix flake metadata; nix flake lock
│  └─ Infinite recursion/type error → narrow with nix repl
└─ Yes
   ├─ “not available” / no machine matches
   │  ├─ Wrong system → inspect meta.platforms and builtins.currentSystem
   │  └─ Missing builder feature → inspect requiredSystemFeatures/builders
   ├─ Substitute rejected
   │  ├─ Unknown key → verify trusted-public-keys
   │  ├─ Hash mismatch → stop; preserve evidence; check cache publisher
   │  └─ Cache miss → build locally/remotely or add correct substituter
   ├─ Builder exited non-zero → nix log; rebuild with -L --keep-failed
   └─ Registration/copy failed → check disk, signatures, references, daemon log
```

Commands:

```console
$ nix build .#package --dry-run --show-trace
$ nix build .#package -L --keep-failed
$ nix log .#package
$ nix config show
$ nix store ping
```

## Tree 2: “Works on one machine”

```text
Are lock file and source revision identical?
├─ No → align and commit flake.lock
└─ Yes
   ├─ Systems differ → check system-specific outputs and platform support
   ├─ Impure input used → retry in a clean environment without --impure
   ├─ Cache/build provenance differs → compare NAR hashes; rebuild
   ├─ Runtime state differs → inspect config, credentials, data, kernel
   └─ Closure differs → path-info --json; store diff-closures
```

Do not infer reproducibility from equal output path names in an input-addressed store. Compare content or NAR hashes from independent builds.

## Tree 3: Unexpected dependency or closure growth

```text
Which store path added size?
└─ nix store diff-closures / nix path-info --closure-size
   ├─ Expected package split → select a smaller output (out, lib, dev, doc)
   ├─ Wrapper references tool → inspect wrapper and PATH prefixes
   ├─ Binary references library → inspect RPATH/interpreter
   ├─ Text embeds store path → inspect generated config/metadata
   └─ Propagation pulled package → inspect propagated inputs
```

```console
$ nix why-depends .#package nixpkgs#suspect
$ nix path-info --recursive --size --closure-size .#package
$ nix-store --query --tree "$(nix build --no-link --print-out-paths .#package)"
```

## Tree 4: Daemon or permissions failure

```text
Can the client reach the store?
├─ No → nix store ping; check daemon service/socket
└─ Yes
   ├─ User denied → inspect allowed-users and group membership
   ├─ Option ignored/forbidden → option may require a trusted user
   ├─ Store read-only/full → inspect mount and free space/inodes
   └─ Invalid path → verify/repair through Nix; never edit DB manually
```

## Tree 5: Remote builder unused

```text
Does nix store ping --store ssh-ng://... succeed?
├─ No → fix SSH identity, host key, remote daemon, or store URI
└─ Yes
   ├─ System mismatch → correct builder systems
   ├─ Feature mismatch → add valid supported features or change derivation
   ├─ Local result/cache hit → test a missing derivation
   ├─ Local build won scheduling → test with --max-jobs 0
   └─ Capacity zero/busy → inspect builder job count and logs
```

## Tree 6: Secret may have leaked

```text
Was the value evaluated, passed to a builder, logged, or written to the store?
├─ No/uncertain → search derivation JSON, logs, outputs, cache metadata
└─ Yes → treat as disclosure
         1. Revoke/rotate immediately.
         2. Stop publishing affected cache objects and logs.
         3. Remove roots and apply retention procedures.
         4. Replace with runtime secret provisioning.
         5. Document scope; GC alone is not reliable erasure.
```

## Common misconceptions

- Retrying repeatedly is not diagnosis; change one variable and capture evidence.
- `--impure`, disabled sandboxing, and disabled signature checks can hide a cause while increasing risk.
- Garbage collection does not revoke a copied secret or remove it from remote caches and backups.
- A cache miss is not a cache integrity failure.

## Recap

Classify the phase, preserve the original error, test one branch, and compare explicit identities: source revision, lock file, system, derivation, closure, and NAR hash.

## Exercises

1. Take three past failures and place each in one tree before describing the fix.
2. Design an evidence bundle for a cache hash mismatch.
3. Simulate an unavailable remote builder and distinguish connectivity from scheduler eligibility.

## Official links

- [Nix troubleshooting](https://nix.dev/manual/nix/latest/troubleshooting.html)
- [Common environment variables](https://nix.dev/manual/nix/latest/command-ref/env-common.html)
- [Nix configuration](https://nix.dev/manual/nix/latest/command-ref/conf-file.html)
- [Repairing store paths](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-store-repair-path.html)
