# 1. A Mental Model of Nix

## Objectives

By the end of this chapter, you will be able to:

- distinguish Nix the language, package manager, store, and build system;
- explain how Nix differs from a conventional package manager and from Docker;
- choose between a native installation and a Docker learning environment;
- run modern `nix` commands with the required experimental features.

## One Name, Several Related Ideas

Nix is easiest to learn when you separate four layers:

1. **The Nix language** describes values and computations. Evaluating an expression does not normally build software.
2. **The package manager** installs, upgrades, and removes packages without overwriting them in place.
3. **The Nix store** holds immutable build results under `/nix/store`.
4. **The build system** realizes derivations: precise build recipes whose outputs enter the store.

The common thread is explicit dependency tracking. A conventional installer might copy `bin/tool` into `/usr/local/bin` and silently depend on whatever libraries happen to be installed. Nix instead gives each result a store path containing a hash derived from its build identity, such as:

```text
/nix/store/7r3...-hello-2.12.2
```

Different builds can coexist because they have different paths. “Installing” usually means making selected store paths reachable through a user-facing profile, not copying their files.

## Nix and Docker Solve Different Problems

Docker packages a process environment as an image and uses kernel isolation at runtime. Nix computes, builds, stores, and composes dependency graphs. They overlap in reproducibility and deployment, but neither replaces the other:

- A Docker layer is ordered filesystem mutation; a Nix store result is immutable and addressed by build identity or content.
- Docker normally targets Linux containers; Nix runs natively on Linux and macOS.
- A container can contain accidental state from earlier layers. Nix builds try to expose declared inputs.
- Nix can build container images, and Docker can provide a disposable place to learn Nix.

Inside Docker, `/nix` disappears when the container is removed unless you attach a volume. Docker examples in this book are therefore excellent for experiments but do not constitute a persistent native setup.

## Disposable Docker Environment

Most examples use the official `nixos/nix` image:

```console
$ docker run --rm -it nixos/nix
```

Inside that shell, enable the modern command interface for the current invocation:

```console
# nix --extra-experimental-features 'nix-command flakes' --version
# nix --extra-experimental-features 'nix-command flakes' eval --expr '1 + 2'
3
```

This book uses the modern `nix` command because it groups discovery (`search`), development (`shell`), building (`build`), inspection (`path-info`), and maintenance (`store gc`) coherently. Some subcommands remain marked experimental, so examples pass feature flags explicitly. `flakes` is enabled only because several modern commands parse flake-style installables; learning flakes is not required here.

For less repetition in a disposable container:

```console
# mkdir -p /etc/nix
# printf '%s\n' 'experimental-features = nix-command flakes' >> /etc/nix/nix.conf
# nix eval --expr 'builtins.nixVersion'
```

## Native Installation

A native installation is appropriate when you want persistent profiles, development shells, and store caching. Follow the current official installation instructions rather than copying an old command from a blog.

Two installation shapes matter:

- **Single-user installation**: the invoking user owns the store machinery. It is simpler but offers less separation.
- **Multi-user/daemon installation**: users submit operations to a privileged Nix daemon. Builds run under dedicated build users, improving isolation. This is typical on shared Linux systems and the standard shape on macOS.

Native Nix changes system-level state, including `/nix`, shell initialization, and possibly daemon configuration. Docker does not test host integration, macOS builders, launchd/systemd behavior, or permissions in a multi-user setup.

After native installation:

```console
$ nix --version
$ nix config show experimental-features
$ nix store ping
```

Enable features in `~/.config/nix/nix.conf` for one user or the relevant system `nix.conf`:

```ini
experimental-features = nix-command flakes
```

## Reading Command Examples

Prompts beginning with `$` run as an ordinary native user. Prompts beginning with `#` are shown inside the official container, whose default user is root. Do not type the prompt character.

Use `nix help-stores`, `nix help`, and command-specific `--help` instead of assuming flags from legacy commands:

```console
# nix store --help
# nix eval --help
# nix derivation --help
```

## Common Misconceptions

- **“Nix is an operating system.”** NixOS is an operating system built with Nix; Nix itself also works on other Linux distributions and macOS.
- **“Nix is just Docker without containers.”** Nix models build dependencies and store objects; Docker primarily models images and runtime isolation.
- **“Installing a package mutates it into the system.”** Nix adds an immutable store object and changes a reference such as a profile generation.
- **“Experimental means unusable.”** The modern CLI is widely used, but its compatibility guarantees differ from stable interfaces.
- **“Docker proves native behavior.”** It proves Linux-container behavior, not host integration or macOS behavior.

## Recap

Nix evaluates descriptions, realizes build recipes, stores immutable results, and exposes selected results through references such as profiles. Docker is a useful disposable classroom, while a native daemon-backed installation is the persistent, better-isolated workstation setup.

## Exercises

1. Start an ephemeral `nixos/nix` container and evaluate `builtins.currentSystem`.
2. Compare `nix --help` with `nix store --help`. Which command groups are top-level?
3. Explain why deleting a container loses its Nix store.
4. Write one sentence each describing Nix language, Nix store, and NixOS without using the three terms interchangeably.

## Official Sources

- [Nix installation](https://nixos.org/download/)
- [Nix manual: introduction](https://nix.dev/manual/nix/latest/introduction)
- [Nix manual: experimental commands](https://nix.dev/manual/nix/latest/command-ref/experimental-commands)
- [Nix Docker image](https://hub.docker.com/r/nixos/nix)
- [NixOS manual](https://nixos.org/manual/nixos/stable/)
