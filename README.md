# Nix, From First Principles

A practical book and lab repository for learning the Nix language, package
manager, Nixpkgs, flakes, the module system, NixOS, Home Manager, nix-darwin,
and the machinery beneath them.

This guide is intentionally broad, but “all Nix concepts” is not a finite
target: Nixpkgs alone changes every day. The goal is to give you the mental
models and tools needed to understand unfamiliar Nix code, verify claims
against primary documentation, and design maintainable systems.

## Start here

1. Install [Docker Desktop](https://docs.docker.com/desktop/) or Docker Engine
   with the Compose plugin.
2. Open the searchable book at <http://localhost:8000>:

   ```console
   docker compose up docs
   ```

   Pages reload as Markdown files change. Stop the server with `Ctrl-C`, or
   run it in the background with `docker compose up -d docs` and later use
   `docker compose down`.

3. Start the portable lab:

   ```console
   ./scripts/lab
   ```

4. Inside the container, verify the workspace:

   ```console
   nix flake show
   nix flake check
   ```

5. Follow the chapters in [SUMMARY.md](SUMMARY.md).

The repository is mounted at `/workspace`, and the Compose volume preserves
the Nix store and learner home between sessions. Run `./scripts/lab down` to
remove the lab containers. On native Linux with a host UID/GID other than
1000, build the image before first use with:

```console
LAB_UID="$(id -u)" LAB_GID="$(id -g)" ./scripts/lab build
```

If those IDs change later, recreate the lab volumes with
`docker compose down --volumes` before rebuilding; that deliberately discards
the lab's cached store, profiles, and home state.

To verify that every documentation page builds without warnings:

```console
docker compose run --rm docs build --strict
```

> Docker is the default environment for package-manager and language labs. A
> container is not a booted NixOS machine. NixOS boot, service, and VM labs
> are marked separately and may require Linux, KVM, or a real NixOS host.

## Choose a learning track

| Goal                  | Suggested route                                                         |
| --------------------- | ----------------------------------------------------------------------- |
| Complete curriculum   | Read every chapter in order                                             |
| Application developer | Foundations → Language → Builds → Flakes → Packaging → Operations       |
| Package maintainer    | Language → Builds → Flakes → Nixpkgs → Internals                        |
| NixOS administrator   | Foundations → Language → Flakes → Modules → Systems → Operations        |
| macOS configuration   | Foundations → Language → Flakes → Modules → Home Manager and nix-darwin |
| Advanced/debugging    | Builds → Modules → Operations → Internals → Appendices                  |

The tracks are shortcuts, not separate editions. Concepts deliberately recur
at increasing depth.

## Platform labels

Chapters and labs use these labels:

- **Docker** — runs in the supplied Linux container.
- **Linux** — requires a native Linux host.
- **NixOS** — requires NixOS or NixOS evaluation/VM tooling.
- **macOS** — runs with native Nix on Darwin.
- **KVM/privileged** — needs virtualization or elevated container access.
- **Networked** — downloads sources or substitutes.
- **Legacy** — useful for existing code, but not the default taught here.
- **Experimental** — behavior or interfaces may still change.

## How to study

For each chapter:

1. Predict the result of each expression or command.
2. Run it in the lab.
3. Explain which phase is evaluation and which is realization.
4. Inspect the result with `nix derivation show`, `nix path-info`, or
   `nix-store --query --references`.
5. Complete the exercises before opening `solutions/`.

Keep three questions in mind:

1. **What is evaluated?** Nix code computes values and derivation graphs.
2. **What is realized?** Builders produce immutable store objects.
3. **What keeps it alive?** Roots and references determine reachability.

## Repository map

- `docs/` — the book.
- `examples/` — small runnable examples referenced by chapters.
- `exercises/` — tasks with incomplete or guided inputs.
- `solutions/` — worked solutions.
- `flake.nix` — development shell, apps, packages, and checks.
- `Dockerfile`, `compose.yaml` — reproducible Linux lab.
- `scripts/lab` — enter or manage the lab.
- `scripts/check` — repository checks.

## Command conventions

Commands beginning with `$` run as an unprivileged user; do not type the `$`.
Commands beginning with `#` require root. Examples generally use the modern
`nix` command and flakes. Legacy equivalents are included where they explain
existing projects or lower-level behavior.

Nix code is formatted with `nixfmt`. Examples avoid `--impure` unless impurity
is the subject of the lesson.

## Version policy

The Docker base and flake inputs are pinned for repeatability. The prose links
to official manuals because exact command flags, options, package versions,
and experimental feature status evolve. When prose and your installed Nix
disagree, check:

```console
nix --version
nix show-config
nix help
```

Then consult the
[official reference map](docs/appendices/glossary-references-and-next-steps.md).

## Safety

- Nix store paths are world-readable by default; never place plaintext secrets
  in Nix expressions, flake inputs, derivation arguments, or generated store
  files.
- Read commands before running them, especially garbage collection, system
  activation, remote deployment, and cache signing.
- A successful build does not prove bit-for-bit reproducibility or software
  trust. The security chapters separate integrity, provenance, isolation, and
  reproducibility.

## License

The guide is provided for learning. Code snippets are small educational
examples; linked upstream documentation remains under its respective license.
