# Part 4 — Flakes and Reproducible Projects

## Chapter 1: The Flake Model

**Platforms:** `[Linux]` `[macOS]` `[NixOS]`

### Objectives

- Understand what a flake does—and what it does not guarantee.
- Write inputs, outputs, and system-specific attributes without unnecessary abstraction.
- Evaluate, inspect, build, run, and develop from a flake reference.
- Interoperate deliberately with projects that still use `default.nix` or `shell.nix`.

### Inputs, outputs, and purity

A flake is a source tree containing `flake.nix` plus a standardized way to identify dependencies and expose results. Its `inputs` describe other flakes or source archives. Its `outputs` function receives the resolved inputs (including `self`) and returns an attribute set. Flakes improve reproducibility by pinning input revisions in `flake.lock` and by evaluating from a source snapshot. They do not make impure build scripts pure, freeze network services used at runtime, or guarantee bit-for-bit identical output across every machine.

Only files tracked by Git are normally included when a flake is addressed through a Git working tree. A newly created but untracked source file can therefore appear “missing” during evaluation. `path:` references snapshot the path directly; be explicit when that distinction matters.

```nix
{
  description = "A small multi-platform package";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs { inherit system; };
    in {
      packages = forAllSystems (system: {
        default = (pkgsFor system).hello;
      });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/hello";
        };
      });

      devShells = forAllSystems (system: {
        default = (pkgsFor system).mkShell {
          packages = [ (pkgsFor system).nil ];
        };
      });
    };
}
```

Common commands:

```console
nix flake show
nix flake metadata
nix build
nix run
nix develop
nix eval .#packages.x86_64-linux.default.name
```

The `.#` syntax is a flake reference followed by an attribute selector. Commands apply their own search rules, so `nix build .#hello` searches package-shaped outputs while `nix run .#hello` searches app and package outputs. Use a full path when ambiguity would hide intent.

### Legacy interoperability

Flakes and classic expressions can coexist:

```nix
# default.nix
(builtins.getFlake (toString ./.)).packages.${builtins.currentSystem}.default
```

`builtins.getFlake` requires a locked reference unless used with an absolute path in an impure evaluation. Conversely, a flake can import a legacy tree:

```nix
outputs = { self, nixpkgs }: {
  packages.x86_64-linux.legacy =
    import ./legacy/default.nix {
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    };
};
```

For consumers that do not enable flakes, keep a thin `default.nix` compatibility entry point. Do not duplicate dependency pins in several files; choose one source of truth and make adapters call it. `flake-compat` is a third-party adapter often used for older Nix, but it is not part of Nix itself.

### Common misconceptions

- **“A flake must be published on GitHub.”** Local paths, Git repositories, tarballs, and supported registries all work.
- **“Flake outputs may only use standardized names.”** Outputs may contain arbitrary attributes, but Nix commands only discover conventional schemas automatically.
- **“A lock file pins my entire runtime.”** It pins flake inputs, not external APIs, mutable container tags, or data fetched by uncontrolled build code.
- **“`builtins.currentSystem` is portable.”** It depends on impure evaluator state and is unavailable in pure evaluation; pass systems explicitly.

### Recap

Flakes make dependency identity and discoverable outputs explicit. Keep system handling visible, pin dependencies, inspect exact output paths, and use narrow adapters for legacy consumers.

### Exercises

1. Add `aarch64-linux` to a two-system flake and inspect its outputs without building them.
2. Expose one package both as `packages.<system>.default` and an app.
3. Write a legacy `default.nix` adapter and explain its pure-evaluation limitation.
4. Demonstrate the difference between a tracked and an untracked file in a Git-backed flake.

### Official links

- [Nix flake command reference](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake)
- [`nix flake init` command reference](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake-init)
- [Flake format](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake#flake-format)
- [`builtins.getFlake`](https://nix.dev/manual/nix/latest/language/builtins.html#builtins-getFlake)

## Chapter 2: Standard Output Schemas

**Platforms:** `[Linux]` `[macOS]` `[NixOS]`

### Objectives

- Recognize every standard top-level flake output.
- Know which outputs are system-indexed and which are not.
- Choose outputs that match command-line and module consumers.

### Complete schema map

The conventional schema supported by modern Nix is:

```nix
{
  checks.<system>.<name> = derivation;
  packages.<system>.<name> = derivation;
  packages.<system>.default = derivation;
  apps.<system>.<name> = { type = "app"; program = "/nix/store/..."; };
  apps.<system>.default = { type = "app"; program = "/nix/store/..."; };
  devShells.<system>.<name> = derivation;
  devShells.<system>.default = derivation;
  formatter.<system> = derivation;
  bundlers.<system>.<name> = drv: derivation;
  bundlers.<system>.default = drv: derivation;

  legacyPackages.<system> = attrset;

  overlays.<name> = final: prev: { };
  overlays.default = final: prev: { };

  nixosModules.<name> = { config, lib, pkgs, ... }: { };
  nixosModules.default = { config, lib, pkgs, ... }: { };
  darwinModules.<name> = { config, lib, pkgs, ... }: { };
  darwinModules.default = { config, lib, pkgs, ... }: { };
  homeModules.<name> = { config, lib, pkgs, ... }: { };
  homeModules.default = { config, lib, pkgs, ... }: { };

  nixosConfigurations.<hostname> = nixpkgs.lib.nixosSystem { ... };
  darwinConfigurations.<hostname> = /* nix-darwin system */;
  homeConfigurations.<name> =
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [ ./home.nix ];
    };

  hydraJobs.<name> = derivation-or-jobset;
  templates.<name> = { path = ./template; description = "..."; };
  templates.default = { path = ./template; description = "..."; };
};
```

The Nix reference schema includes `checks`, `packages`, `apps`, `devShells`,
`formatter`, `bundlers`, `legacyPackages`, `overlays`, `nixosModules`,
`nixosConfigurations`, `hydraJobs`, and `templates`. `darwinModules`,
`darwinConfigurations`, `homeModules`, and `homeConfigurations` are ecosystem
conventions consumed by nix-darwin and Home Manager rather than core Nix
command schemas. A Home Manager configuration is an evaluated configuration
attribute set; its buildable activation derivation is available as
`.activationPackage`. That distinction matters when diagnosing why
`nix flake check` does not automatically validate an ecosystem output.

`bundlers.<system>.<name>` and `bundlers.<system>.default` are current schema
entries. Avoid designing new public APIs around deprecated `defaultPackage`,
`defaultApp`, `defaultTemplate`, or `defaultBundler`; use nested `default`
attributes instead.

### Choosing an output

- Put directly buildable artifacts in `packages`; reserve `legacyPackages` for large, recursively evaluated package sets.
- Put executable launch metadata in `apps`. A package with `meta.mainProgram` can also be run by `nix run`.
- Put development environments in `devShells`, usually created with `pkgs.mkShell`.
- Put derivation-valued validation in `checks`; `nix flake check` builds checks for the host system unless directed otherwise.
- Put one source formatter in `formatter` for `nix fmt`.
- Export reusable package transformations through `overlays`.
- Export reusable modules separately from fully assembled system configurations.
- Keep `hydraJobs` free of values Hydra cannot traverse as jobs.

```nix
checks = forAllSystems (system:
  let pkgs = pkgsFor system;
  in {
    package = self.packages.${system}.default;
    formatting = pkgs.runCommand "format-check" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
      nixfmt --check ${./.}
      touch $out
    '';
  });
```

Do not use `eachDefaultSystem` blindly. A library helper can reduce repetition, but the supported platform list remains an API decision and should be visible and tested.

### Common misconceptions

- **“Every output has a `<system>` level.”** Modules, overlays, templates, and assembled configurations generally do not.
- **“`legacyPackages` means old packages.”** It is a non-flat package namespace, not an age label.
- **“An app’s `program` can be a shell command.”** It must be an absolute executable path, normally in the Nix store.
- **“Checks run on every architecture during local evaluation.”** The command normally checks the current system; CI must provide the architecture matrix.

### Recap

Standard names are command interfaces. System-index artifacts that build on a platform; leave reusable modules and named machine configurations keyed by their semantic identity.

### Exercises

1. Add a formatter and verify it with `nix fmt`.
2. Export the same executable as a package and app; compare `nix build` and `nix run`.
3. Add a check that builds the default package.
4. Classify each output above as a core Nix schema or an ecosystem convention.

### Official links

- [Flake output schema](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake#flake-format)
- [`nix flake check`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake-check)
- [`nix develop`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-develop)
- [`nix fmt`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-fmt)

## Chapter 3: Lock Files, Registries, Follows, and Overrides

**Platforms:** `[Linux]` `[macOS]` `[NixOS]`

### Objectives

- Read the graph represented by `flake.lock`.
- Update dependencies narrowly and review lock changes.
- Distinguish registry indirection, input following, and command-line overrides.
- Avoid accidental dependency duplication.

### The locked graph

`flake.lock` records nodes, original references, resolved references, immutable revisions or content hashes, and edges between inputs. It is generated data but should normally be committed for applications and system configurations. Libraries may also commit it to make development and CI reproducible; downstream users can still override inputs.

```console
nix flake lock
nix flake update
nix flake update nixpkgs
nix flake metadata
```

Use the command forms supported by your installed Nix version (`nix flake lock --update-input` is common on older releases). A focused update reduces unrelated churn. Review revision, timestamp, owner/repository, and `narHash`; a lock update is a dependency change, not clerical noise.

### Follows and graph deduplication

Suppose Home Manager declares its own `nixpkgs` input. Make it follow the root pin when compatibility permits:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

`follows` redirects an input edge. It can reduce lock-file duplication and ensure packages and modules use one Nixpkgs revision. It is not always correct: an input may intentionally require a different branch or API level. Check that project’s compatibility policy before forcing it to follow.

### Registries

A registry maps short identifiers such as `nixpkgs` to flake references. Registries can exist at global, system, and user scopes:

```console
nix registry list
nix registry add nixpkgs github:NixOS/nixpkgs/nixos-unstable
nix registry remove nixpkgs
```

`nix registry add` and `nix registry remove` modify the user registry unless
another scope is explicitly selected. User and system registries resolve
command-line references, but indirect input references declared inside
`flake.nix` consult the global registry rather than those local scopes.
Registries are convenient for interactive references, but an unlocked
indirect reference is ambient state. In shared projects, declare important
inputs in `flake.nix` and commit the lock file. NixOS can manage registry
entries through system configuration, allowing a fleet to expose intentional
command-line aliases.

### Overrides

Temporarily replace a transitive or direct input without editing the source:

```console
nix build .#my-package \
  --override-input nixpkgs github:NixOS/nixpkgs/nixos-24.11

nix flake metadata \
  --override-input dependency/nixpkgs path:/work/nixpkgs
```

An override affects that invocation and is valuable for testing forks or local changes. An input declaration can also set `flake = false` for a source that has no `flake.nix`:

```nix
inputs.vendor = {
  url = "github:example/vendor/v1.2.3";
  flake = false;
};
```

The result passed to `outputs` is then source metadata with an `outPath`, not a flake output set.

### Common misconceptions

- **“`follows` copies another URL.”** It changes a graph edge to point at another locked node.
- **“A registry is a lock file.”** Registry mappings choose references; lock files pin the resolved graph for a flake.
- **“Deleting `flake.lock` is the normal update workflow.”** It discards all pins and causes broad churn; update targeted inputs.
- **“`--override-input` edits the lock permanently.”** It is an invocation-scoped override unless a subsequent explicit lock operation records a change.

### Recap

The lock file is a reviewable dependency graph. Use follows only when compatibility allows one shared input, registries for controlled shorthand, and overrides for experiments.

### Exercises

1. Draw the lock graph for a root with two inputs that each depend on Nixpkgs.
2. Add `follows`, regenerate the lock, and compare node counts.
3. Override Nixpkgs with a local checkout for one build.
4. Establish a policy for application and library lock files.

### Official links

- [`nix flake lock`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake-lock)
- [`nix flake update`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake-update)
- [`nix registry`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-registry)
- [Flake references](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake#flake-references)

## Chapter 4: Flake Design and Compatibility

**Platforms:** `[Linux]` `[macOS]` `[NixOS]`

### Objectives

- Design a flake API that remains understandable to downstream consumers.
- Separate package, module, and host composition layers.
- Diagnose purity and source-snapshot failures.

### Stable boundaries

Treat output paths as a public API. A practical repository separates:

1. package expressions, parameterized by `pkgs`;
2. reusable modules, which declare options and configuration;
3. host definitions, which choose inputs, systems, users, and policy;
4. thin flake wiring that exports the three.

Pass non-module values through `specialArgs` for NixOS or `extraSpecialArgs` for Home Manager, but avoid passing a giant self-referential context when a narrow argument is sufficient. Modules already receive `lib`, `config`, `options`, and usually `pkgs`.

```nix
nixosConfigurations.web = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = { inherit inputs; };
  modules = [
    ./hosts/web.nix
    self.nixosModules.default
  ];
};
```

Pin source inputs, but let derivations use Nix’s normal fixed-output fetchers. Avoid reading the current directory, environment variables, wall-clock time, or host files during pure evaluation. If evaluation reports that a path does not exist, check Git tracking and path construction before reaching for `--impure`.

Use `nix flake check` as the minimum structural gate, then explicitly build important packages and host toplevels in CI. Evaluation success does not prove activation safety.

### Common misconceptions

- **“All configuration belongs in `flake.nix`.”** Large inline output functions become hard to reuse and test.
- **“`--impure` fixes flake problems.”** It may hide undeclared dependencies and machine-specific assumptions.
- **“One global package set is always best.”** Sharing is useful, but cross targets and policy differences may require distinct imports.
- **“If `nix flake check` passes, deployment is safe.”** Activation, boot, networking, and service migration require separate tests.

### Recap

Keep the flake entry point declarative and small. Export stable package and module APIs, assemble hosts explicitly, and test both evaluation and activation-relevant artifacts.

### Exercises

1. Refactor an inline host configuration into a reusable module and host file.
2. Add a CI build target for `config.system.build.toplevel`.
3. Find three sources of evaluator impurity and replace them with explicit inputs.
4. Document which output paths your downstream users may rely on.

### Official links

- [Nix language purity](https://nix.dev/manual/nix/latest/language/)
- [NixOS configuration](https://nixos.org/manual/nixos/stable/#sec-changing-config)
- [`nixosSystem` source](https://github.com/NixOS/nixpkgs/blob/master/nixos/lib/eval-config.nix)
- [Nix command reference](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix)
