# Remote Builds, Binary Caches, and Trust

## Objectives

By the end of this chapter, you should be able to:

- distinguish distributed builders from substituters;
- configure and diagnose remote builds;
- explain NAR, NARInfo, cache signatures, and trust policy; and
- reason about what a valid signature does and does not guarantee.

## Remote and distributed builds

A remote builder executes derivations for another Nix store. The coordinator selects eligible machines according to system type, required and supported features, job capacity, speed factor, and availability. Inputs are copied to the builder; successful outputs are copied back and registered.

Example daemon configuration:

```ini
builders = ssh-ng://nix@builder-a x86_64-linux /etc/nix/builder_ed25519 8 1 kvm,big-parallel - ; ssh-ng://nix@builder-b aarch64-linux /etc/nix/builder_ed25519 4 1 big-parallel -
builders-use-substitutes = true
```

The exact `builders` field format is easy to misread. Prefer `nix build --builders '...'` while testing, then consult the current manual before committing configuration.

```console
$ nix store ping --store ssh-ng://nix@builder-a
$ nix build nixpkgs#hello --builders 'ssh-ng://nix@builder-a' -L
$ nix build .#package --max-jobs 0 --builders @/etc/nix/machines
```

`--max-jobs 0` prevents local builds, which is useful for proving that dispatch works. It can also make a build impossible when no remote machine matches.

## Binary caches

A binary cache is a substituter: it serves already-built store objects. A typical HTTP cache exposes:

- `<store-hash>.narinfo`: metadata naming the store path, NAR URL, compression, compressed file hash and size, unpacked NAR hash and size, references, deriver, and signatures;
- a compressed `.nar` payload: the Nix Archive serialization of the store object; and
- optional cache metadata such as `nix-cache-info`.

The NAR hash authenticates the canonical uncompressed archive. The file hash authenticates the downloadable compressed object. They protect different stages.

Configure caches and public keys:

```ini
substituters = https://cache.nixos.org https://cache.example.org
trusted-public-keys = cache.nixos.org-1:... cache.example.org-1:BASE64KEY
```

Inspect cache behavior:

```console
$ nix config show | grep -E '^(substituters|trusted-public-keys|require-sigs) ='
$ nix path-info --store https://cache.nixos.org nixpkgs#hello
$ nix build nixpkgs#hello --dry-run --substituters https://cache.nixos.org
$ nix store verify --sigs-needed 1 --trusted-public-keys 'cache.example.org-1:...'
```

## Signatures and trust

A cache signature binds selected path metadata, including the store path and NAR hash, to a signing key. It says that the key holder vouches for that object. It does not prove source provenance, reproducibility, absence of malware, or that the signing host was uncompromised.

Trust has several layers:

- TLS protects a network connection but is not a replacement for cache signatures.
- `trusted-public-keys` identifies acceptable cache signers.
- `trusted-users` grants powerful daemon privileges, including the ability to influence settings that ordinary users cannot. Treat membership as close to root-level trust.
- Content hashes detect corruption; authorization policy decides whose content is accepted.

Never distribute private cache signing keys to builders unnecessarily. Sign on a controlled publishing system or use a narrowly scoped signing service.

## Common misconceptions

- **“Remote builder” and “binary cache” are synonyms.** Builders execute work; caches distribute completed work.
- **“HTTPS makes `trusted-public-keys` unnecessary.”** TLS and Nix signatures cover different trust boundaries.
- **“A signed result is reproducible.”** A signature is an attestation by a key, not an independent rebuild.
- **“`builders-use-substitutes` makes the coordinator's caches automatically available.”** It allows builders to use their own configured substituters.
- **“Cross-compilation and remote native building are equivalent.”** They have different platforms, toolchains, failure modes, and performance characteristics.

## Recap

Distributed builds move build execution; binary caches move realized closures. NARInfo connects a store path to its canonical archive and references, while signatures establish publisher trust. Hashes establish integrity, not goodness.

## Exercises

1. Force a harmless package to build only on a remote machine and inspect logs on both ends.
2. Fetch one `.narinfo` file and label each hash, size, reference, and signature field.
3. Temporarily omit a cache public key and record the resulting trust error.
4. Write a key-rotation procedure that permits overlap without accepting unsigned paths.

## Official links

- [Distributed builds](https://nix.dev/manual/nix/latest/advanced-topics/distributed-builds.html)
- [Serving a binary cache](https://nix.dev/manual/nix/latest/package-management/binary-cache-substituter.html)
- [Nix Archive format](https://nix.dev/manual/nix/latest/store/file-system-object/content-address.html#serial-nix-archive)
- [`nix store verify`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-store-verify.html)
- [Nix configuration options](https://nix.dev/manual/nix/latest/command-ref/conf-file.html)
