# Daily Development with Nix

**Platforms:** `[Linux]` `[macOS]` `[NixOS]` `[Editors]`

## Objectives

- enter a pinned development shell automatically and safely;
- connect editors and language tooling to the same environment as the terminal;
- design focused language shells; and
- update shared pins without surprising the team.

## direnv and nix-direnv

Install `direnv` with your operating system or home configuration, then install
`nix-direnv` and hook direnv into your interactive shell. For example, the
shell hook is commonly:

```sh
eval "$(direnv hook bash)" # use the matching zsh/fish command when appropriate
```

Configure nix-direnv as described by its installation method. On NixOS or Home
Manager, prefer their modules so every workstation receives the same
integration. The repository `.envrc` is deliberately only:

```sh
use flake
```

At the repository root, run `direnv allow` after reviewing `.envrc`,
`flake.nix`, `flake.lock`, and any imported Nix code. `direnv allow` is a trust
decision, not a harmless setup step: entering a directory evaluates shell code
and `nix develop` may build dependencies and execute the flake's `shellHook`.
Re-review changes before allowing again. Never auto-allow arbitrary checkouts,
and do not place tokens in `.envrc`; keep secrets in an external credential
manager or ignored, permission-restricted runtime file.

`nix-direnv` caches development environments, which makes repeated entry much
faster. If a shell looks stale, use `direnv reload`; after pin changes, allow
nix-direnv to rebuild its cache. Do not commit generated `.direnv` state.

Without direnv, the explicit equivalent remains useful for diagnosis:

```console
nix develop
nix develop .#backend
nix develop --command bash -c 'command -v python; python --version'
```

## Editors use the shell too

Launching an editor from an activated terminal is the simplest integration:

```console
direnv allow
code .
```

Editor direnv extensions can update the environment of an already-running
editor. Treat extensions as another trust boundary and verify that the
extension uses the repository environment rather than a stale global one.
Language servers, formatters, compilers, and test runners should resolve from
the development shell. A terminal using Nix while the editor silently uses
global tools creates version-dependent failures.

For reliable team setup:

1. put language servers and formatters in `devShells`, not only in editor settings;
2. commit editor settings only when they are portable and do not contain host paths;
3. configure the editor to run the repository formatter and test commands;
4. verify with `command -v <tool>` in both the terminal and editor task; and
5. keep generated indexes and per-user extension choices out of Nix unless the team intentionally manages them.

## Language-focused shells

Keep one small default shell for common work and named shells for specialized
stacks. This avoids making documentation or frontend contributors download
every backend and infrastructure tool.

```nix
devShells.${system} = {
  default = pkgs.mkShell {
    packages = with pkgs; [ git nixfmt-rfc-style ];
  };

  python = pkgs.mkShell {
    packages = with pkgs; [ python312 python312Packages.pytest ruff pyright ];
  };

  rust = pkgs.mkShell {
    packages = with pkgs; [ cargo rustc rust-analyzer clippy rustfmt ];
  };

  node = pkgs.mkShell {
    packages = with pkgs; [ nodejs_22 pnpm nodePackages.typescript-language-server ];
  };
};
```

Select one with `nix develop .#python` or `use flake .#python` in a
directory-specific `.envrc`. A development shell supplies tools and
environment; the language package manager may still manage project
dependencies. Commit its lock file, avoid globally installed packages, and
ensure native dependencies are declared in Nix.

`shellHook` should be fast, deterministic, and free of network access, secret
reads, migrations, or mutable setup. Put explicit setup in a documented command
instead of running it whenever someone enters the directory.

## Team pinning and updates

Commit `flake.lock` and make CI use it unchanged. New team members then receive
the same input graph rather than whatever a registry or moving branch resolves
that day. Prefer a focused update:

```console
nix flake update nixpkgs
nix flake metadata
nix flake check --show-trace
./scripts/check
```

Older Nix versions may use `nix flake lock --update-input nixpkgs`. Review the
old and new revisions, `narHash`, transitive graph changes, release notes, and
resulting package or system changes. Do not delete the lock file merely to
update one input.

A practical policy assigns an update owner and cadence, uses a pull request for
lock changes, runs the complete platform matrix, and keeps unrelated source
changes separate. Security updates can use an expedited path but still require
review and tests. Roll back a bad update by reverting the reviewed lock-file
commit, not by editing generated lock JSON manually. Automated update tools
should open reviewable pull requests; they should not merge solely because
evaluation succeeded.

## Common misconceptions

- **“`direnv allow` only loads environment variables.”** It authorizes project-controlled shell evaluation.
- **“The editor automatically inherits my terminal.”** GUI-launched editors often have a different environment.
- **“One giant shell is simpler.”** It increases downloads, collisions, and update impact.
- **“A committed lock file never changes.”** Pins should change through deliberate, tested reviews.
- **“`shellHook` is a safe bootstrap script.”** It executes on shell entry and should have minimal side effects.

## Recap

Use a reviewed, minimal `.envrc`, let nix-direnv cache the pinned development
shell, and make terminal and editor tools come from that shell. Keep language
shells focused and update shared pins through narrow, tested changes.

## Official links

- [direnv](https://direnv.net/)
- [nix-direnv](https://github.com/nix-community/nix-direnv)
- [`nix develop`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-develop)
- [Nix flake lock files](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake-lock)
