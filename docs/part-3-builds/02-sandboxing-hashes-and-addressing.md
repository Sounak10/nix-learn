# 9. Sandboxing, Hashes, and Addressing

## Objectives

By the end of this chapter, you will be able to:

- explain what the build sandbox does and does not guarantee;
- distinguish input-addressed, fixed-output, and content-addressed results;
- update and verify hashes for fetched content;
- relate hashes, derivations, cache keys, and trust.

## Why Sandbox Builds?

A builder that can read arbitrary host files, use undeclared tools, or contact the network has hidden inputs. Nix's build sandbox restricts the process so declared store inputs and explicitly provided facilities dominate its view.

Inspect the effective setting:

```console
# nix config show sandbox
```

Linux commonly uses namespaces and other kernel isolation. macOS uses its platform sandbox. Exact visibility and defaults vary by platform, installation mode, and configuration.

Sandboxing aims to catch undeclared dependencies. It is not a general-purpose security boundary for executing hostile code. Builders may consume CPU, exploit kernel bugs, or access explicitly granted capabilities. Use stronger isolation where adversarial-code execution is in scope.

## Input-Addressed Derivations

For traditional derivations, output path identity is based mainly on the derivation's inputs and recipe, not a post-build checksum of all output bytes. Change a source path, builder, argument, dependency, platform, or relevant attribute and the derivation identity—and usually output path—changes.

This supports:

- coexistence of variants;
- cache lookup before building;
- precise dependency graphs.

However, equal recipe identity does not mathematically force equal bytes. A nondeterministic builder could produce different bytes for the same input-addressed output path on different machines. Cache signatures establish who vouches for a result, not that all independent builders agree.

## Fixed-Output Derivations

A **fixed-output derivation** declares the expected content hash in advance. Its output identity is tied to that declared hash, allowing Nix to permit operations—commonly network fetching—that ordinary sandboxed builds cannot perform.

Nixpkgs fetchers are the normal interface:

```nix
pkgs.fetchurl {
  url = "https://example.org/source.tar.gz";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
```

Modern expressions use SRI hashes such as `sha256-...`. Older code may use `sha256` attributes or base32 encodings.

To discover a hash for a trusted URL:

```console
# nix store prefetch-file https://example.org/source.tar.gz
```

The command downloads content, places it in the store, and reports its hash and store path. Use a real immutable upstream URL; `example.org` above is illustrative and does not host that archive.

A common development loop is to use an intentionally wrong placeholder hash, run the build, and replace it with the reported actual hash. Never leave a fake hash or silently accept changed upstream bytes. Investigate whether the release was legitimately replaced or the URL is mutable.

## Flat and Recursive Hash Modes

Hash mode matters:

- **flat** hashes a single regular file's bytes;
- **recursive** hashes a canonical serialization of a filesystem tree, commonly NAR format.

The same payload represented under different modes does not have the same digest. Fetcher documentation determines the appropriate mode. Archives are often fetched as flat files; unpacked source trees are represented recursively.

Calculate hashes using current commands:

```console
# printf 'hello\n' >/tmp/message
# nix hash file /tmp/message
# mkdir -p /tmp/tree && cp /tmp/message /tmp/tree/
# nix hash path /tmp/tree
```

`nix hash convert` converts encodings; it does not rehash content under another mode.

## Content-Addressed Store Objects

A content-addressed object is identified from its content, rather than only from a recipe expected to produce it. This improves deduplication and allows stronger statements that a path corresponds to specific bytes.

Nix's content-addressed derivation features have evolved and may require experimental settings. Do not assume every ordinary `/nix/store` output is content-addressed merely because its path contains a hash.

The three models answer different questions:

- **Input-addressed**: which recipe and declared inputs identify this output slot?
- **Fixed-output**: does the result match a hash declared before building?
- **Content-addressed**: which content itself identifies this store object?

## Hashes Are Not Signatures

A hash verifies equality to an expected digest. It does not say who supplied that expectation. If an attacker can replace both an archive and the hash in your source repository, hashing alone does not establish authenticity.

Use upstream release signatures, protected source control, reviewed lock-file changes, and trusted binary-cache signatures as appropriate. Each protects a different link in the supply chain.

## Sandbox Exceptions

Fixed-output builds historically receive network access because their output is verified. Platform-specific derivations, impure host dependencies, and explicitly configured paths can also weaken isolation. Remote builders enforce their own capabilities and settings.

To test whether a local build accidentally depends on the host, rebuilding in a clean Docker environment is useful—but it remains only one Linux environment. Independent rebuilds on different machines are stronger evidence.

## Common Misconceptions

- **“The hash in every store path is a checksum of output bytes.”** Traditional input-addressed outputs encode build identity.
- **“Sandboxing makes hostile builds safe.”** It primarily enforces dependency discipline.
- **“A fixed-output derivation is automatically trustworthy.”** It matches a declared hash; trust in the declaration comes from elsewhere.
- **“Flat and recursive hashes are interchangeable.”** They hash different representations.
- **“Every Nix build is content-addressed.”** Content-addressed outputs are a distinct model and feature set.
- **“A signature proves reproducibility.”** It proves that a key signed metadata.

## Recap

The sandbox reduces hidden builder inputs. Traditional derivations are input-addressed; fixed-output derivations commit to expected content and commonly support fetches; content-addressing derives identity from content. Hash modes and signatures must be interpreted according to the guarantee they actually provide.

## Exercises

1. Inspect your sandbox setting and research its platform-specific meaning.
2. Hash one file with `nix hash file`, then hash its parent tree with `nix hash path`.
3. Prefetch an immutable release archive and record its SRI hash.
4. List three derivation changes that normally alter an input-addressed output path.
5. Explain why a trusted hash can verify bytes but cannot identify the original author.

## Official Sources

- [Nix sandbox configuration](https://nix.dev/manual/nix/latest/command-ref/conf-file#conf-sandbox)
- [File-system objects and NARs](https://nix.dev/manual/nix/latest/store/file-system-object)
- [`nix hash`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-hash)
- [`nix store prefetch-file`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-store-prefetch-file)
- [Content-addressed derivations](https://nix.dev/manual/nix/latest/development/experimental-features#xp-feature-ca-derivations)
- [Nixpkgs fetchers](https://nixos.org/manual/nixpkgs/stable/#chap-pkgs-fetchers)
