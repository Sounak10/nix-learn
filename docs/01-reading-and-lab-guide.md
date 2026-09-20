# Reading and Lab Guide

## Prerequisites

You should be comfortable with a shell, files, environment variables, and
basic programming constructs. Linux administration knowledge is helpful only
for the NixOS sections.

The default lab needs Docker with Compose. Native Nix is optional. On Apple
Silicon, Docker runs the `aarch64-linux` version of the lab; Intel Linux and
macOS normally run `x86_64-linux`. Nix expressions are portable only when
their package and system assumptions are portable.

## Entering the lab

From the repository root:

```console
./scripts/lab
```

The prompt runs as the unprivileged `learner` user. The repository is
`/workspace`. The lab uses a writable single-user Nix store inside Docker; it
does not run the multi-user Nix daemon. The store is isolated from any native
Nix installation on your host.

Useful wrapper commands:

```console
./scripts/lab --version
./scripts/lab flake check
./scripts/lab down
```

If Docker is unavailable, install Nix using the current instructions at
[nix.dev](https://nix.dev/install-nix) and run chapter commands directly.
Native multi-user installation behavior differs from the single container
process, so study the daemon chapter even if the basic commands look alike.

## What Docker can and cannot teach

Docker is well suited for:

- Language evaluation and REPL work.
- Derivations and builds inside a disposable container environment.
- Flakes, package authoring, overlays, and cross-platform evaluation.
- Store inspection, profiles, garbage collection, and binary-cache clients.
- Pure Home Manager builds that do not depend on host desktop services.

Docker does not faithfully model:

- Booting a NixOS generation.
- Managing the host systemd or launchd instance.
- nix-darwin activation.
- Hardware, filesystems, bootloaders, initrd, or desktop sessions.
- KVM-backed NixOS tests unless virtualization is explicitly exposed.
- A hardened production multi-user daemon and its trust boundaries.
- Nix's normal Linux build sandbox: the lab disables it because it already
  runs as an unprivileged user inside Docker. Container isolation is not a
  substitute for learning Nix sandbox configuration.

For those topics, the book starts with pure evaluation and VM builds, then
marks the point where a native host is required.

## Experiment protocol

For each example, use this loop:

### 1. Evaluate

```console
nix eval --file examples/language.nix
```

Ask which files and environment values evaluation can observe. Add
`--show-trace` when an error lacks context.

### 2. Inspect the derivation

```console
nix derivation show .#hello
```

Locate the builder, arguments, environment, input derivations, input sources,
platform, and outputs. The JSON representation is easier to inspect with
`jq`.

### 3. Realize

```console
nix build --print-build-logs .#hello
readlink result
```

Determine whether Nix built locally or downloaded a substitute.

### 4. Inspect the closure

```console
nix path-info -rSh .#hello
nix path-info --recursive .#hello
nix why-depends .#hello /nix/store/<chosen-path-from-the-closure>
```

Choose an actual dependency reported by the first command. Closure members
and their paths differ across platforms and pins; do not assume glibc or mix
the project package with a separately resolved registry package.

### 5. Remove only what you understand

Deleting `result` removes a symlink root, not the store object immediately.
Garbage collection deletes store objects that are unreachable from all known
roots. Never use aggressive collection on a host until you have inspected:

```console
nix-store --gc --print-roots
nix profile history
```

## Flake source visibility

When a directory is inside a Git repository, flake evaluation normally sees
tracked files. A newly created but untracked file may appear missing to Nix.
This is a source-filtering issue, not a language import rule.

For a quick lab you can stage the file, reference `path:.`, or work outside a
Git tree. Do not reach for `--impure` automatically: impurity and source
selection are separate issues.

## Reading errors

Classify failures before changing code:

1. **Parse error** — the expression is not valid syntax.
2. **Evaluation error** — types, attributes, imports, assertions, recursion,
   purity, or system selection failed.
3. **Instantiation/derivation error** — a build description is invalid.
4. **Substitution error** — cache lookup, signature, trust, or network failed.
5. **Build error** — the builder exited unsuccessfully.
6. **Activation error** — the artifact built, but switching the live
   environment failed.

This classification prevents random flag changes from hiding the real issue.

## Exercise policy

Chapter questions test explanation, not memorization. Repository exercises
are runnable and progress from reading expressions to changing packages and
modules. Solutions show one sound approach, not the only possible expression.

When comparing your solution:

- Compare evaluated values and dependency graphs, not formatting alone.
- Run `nix fmt` and `nix flake check`.
- Inspect whether your solution introduced impurity or an unnecessary runtime
  reference.
- Explain platform-specific choices.

## Staying current

Nix spans independently released projects. Record all relevant versions when
asking for help:

```console
nix --version
nix flake metadata
nix eval --raw --impure --expr builtins.currentSystem
docker version
```

Prefer primary references:

- Nix language, command, and store manuals at `nix.dev`.
- Nixpkgs and NixOS manuals at `nixos.org`.
- Home Manager and nix-darwin manuals maintained by their projects.
- Source code and release notes when behavior differs from prose.

The official-reference appendix maps each topic to its authority.
