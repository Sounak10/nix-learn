# 2. The Store, Paths, and the Modern CLI

## Objectives

By the end of this chapter, you will be able to:

- identify store paths and explain why they are immutable;
- distinguish an installable, a derivation path, and an output path;
- use `nix eval`, `nix shell`, `nix build`, and `nix path-info`;
- inspect results without treating `/nix/store` as a directory to edit.

## Store Objects

The Nix store is normally rooted at `/nix/store`. Each direct child is a **store path**:

```text
/nix/store/<digest>-<human-readable-name>
```

The digest prevents unrelated objects with the same readable name from colliding. The name helps humans but is not the identity by itself. Store objects include source snapshots, derivation files, executables, libraries, and complete package outputs.

Store paths are immutable after registration. Never edit one, even if permissions appear to permit it inside a privileged container. Mutation would invalidate Nix's dependency and cache assumptions. Create a new result instead.

## Installables Are Command Inputs

Modern commands accept **installables**: syntax that tells Nix what to operate on. Common forms include:

- a flake reference and attribute, such as `nixpkgs#hello`;
- a store path;
- a local path or flake;
- an expression supplied through `--expr` or standard input.

`nixpkgs#hello` is not itself a store path. It selects an output from the `nixpkgs` flake. Nix may fetch metadata, evaluate Nix code, obtain a derivation, and then substitute or build its output.

## Evaluate Without Building

Evaluation computes language values:

```console
# nix --extra-experimental-features 'nix-command flakes' eval \
    --expr '{ answer = 6 * 7; names = [ "Ada" "Linus" ]; }'
{ answer = 42; names = [ "Ada" "Linus" ]; }
```

Use `--json` when another program will consume the result:

```console
# nix eval --json --expr '{ ok = true; n = 3; }'
{"n":3,"ok":true}
```

Evaluation can still read files, fetch allowed inputs, or compute derivations; “does not build” does not mean “has no effects or I/O under every mode.”

## Run a Temporary Command

`nix shell` adds package outputs to a temporary environment:

```console
# nix shell nixpkgs#hello --command hello
Hello, world!
```

This does not add `hello` to a persistent profile. It ensures the output exists in the store, modifies environment variables for the child process, and runs the command.

## Build and Inspect

`nix build` realizes an installable:

```console
# mkdir -p /tmp/nix-book && cd /tmp/nix-book
# nix build nixpkgs#hello
# readlink -f result
/nix/store/...-hello-...
# ./result/bin/hello
Hello, world!
```

By default, `result` is a symlink in the current directory. It is not the build output itself. The output remains in `/nix/store`; `result` is a garbage-collection root while it exists.

Inspect paths without creating a result link:

```console
# nix path-info nixpkgs#hello
/nix/store/...-hello-...
# nix path-info --json nixpkgs#hello
# nix path-info -S nixpkgs#hello
```

`-S` reports closure size, not merely the size of the package directory.

## Derivation Paths and Output Paths

A derivation path ends in `.drv` and stores a low-level build recipe:

```console
# nix path-info --derivation nixpkgs#hello
/nix/store/...-hello-....drv
```

An output path holds the realized files:

```console
# nix path-info nixpkgs#hello
/nix/store/...-hello-...
```

One derivation may have multiple outputs, commonly separating runtime files, development headers, or documentation. A derivation can exist before its output has been realized.

## Query and Search

Search package metadata:

```console
# nix search nixpkgs hello
```

Show selected package metadata:

```console
# nix eval --json nixpkgs#hello.meta \
    --apply 'm: { inherit (m) description homepage; }'
```

Package search and evaluation may download registry or flake metadata. Pin inputs when reproducibility matters; an unqualified registry name can resolve differently as registries change.

## Common Misconceptions

- **“The hash is a checksum of every package's final bytes.”** Traditional input-addressed output paths primarily encode the derivation's build identity; content-addressed and fixed-output paths follow different rules.
- **“`result` contains a copy.”** It is normally a symlink to the store.
- **“`nix shell` installs globally.”** Its environment is temporary.
- **“A `.drv` is the package.”** It is a serialized build recipe; output paths contain results.
- **“Root can safely patch store files.”** Doing so violates immutability and can corrupt assumptions.

## Recap

The store contains immutable objects with unique paths. Modern CLI commands accept installables, evaluate descriptions, realize outputs, expose temporary environments, and inspect both derivations and outputs.

## Exercises

1. Run `nix path-info -S nixpkgs#hello` and compare it with `du -sh "$(nix path-info nixpkgs#hello)"`. Explain the difference.
2. Build `nixpkgs#cowsay`, inspect `result`, then remove only the symlink.
3. Obtain both the `.drv` path and output path for `hello`.
4. Use `nix eval --json` to emit an attribute set containing a string, Boolean, and list.

## Official Sources

- [Nix store paths](https://nix.dev/manual/nix/latest/store/store-path)
- [New CLI command reference](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix)
- [`nix build`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-build)
- [`nix shell`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-shell)
- [`nix path-info`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-path-info)
