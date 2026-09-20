# Part 5 — Nixpkgs and Package Engineering

## Chapter 1: The Package Set, `lib`, and `callPackage`

**Platforms:** `[Linux]` `[macOS]`

### Objectives

- Understand Nixpkgs as a parameterized, recursively connected package set.
- Use `lib` for common data, string, version, source, and platform operations.
- Write package functions that work with `callPackage`.

### Importing Nixpkgs

Nixpkgs is both a repository of expressions and the package set produced by importing it:

```nix
let
  pkgs = import <nixpkgs> {
    system = builtins.currentSystem;
    config.allowUnfree = false;
    overlays = [];
  };
in pkgs.hello
```

In a flake, pass a concrete system instead of relying on `<nixpkgs>` or `builtins.currentSystem`:

```nix
pkgs = import nixpkgs {
  inherit system;
  config = { allowUnfree = false; };
};
```

Import configuration changes package-set policy. Multiple imports cost evaluation time and can accidentally mix package identities. Construct package sets at clear composition boundaries and pass `pkgs` or dependencies onward.

`pkgs.lib` is Nixpkgs’ utility library. Common families include `lib.attrsets`, `lists`, `strings`, `versions`, `filesystem`, `sources`, `licenses`, `platforms`, `types`, and module helpers. Prefer a documented `lib` function over local reinvention, but do not use undocumented internals as a stable API.

### Dependency injection with `callPackage`

A package expression is normally a function:

```nix
{ lib
, stdenv
, fetchFromGitHub
, pkg-config
, openssl
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "example";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "example";
    repo = "example";
    rev = "v${finalAttrs.version}";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  meta = {
    description = "An example package";
    homepage = "https://example.invalid";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "example";
  };
})
```

`pkgs.callPackage ./package.nix { }` inspects the function’s formal arguments, fills matching names from its package scope, and merges explicit arguments. Explicit values win:

```nix
pkgs.callPackage ./package.nix {
  openssl = pkgs.openssl_3;
}
```

This is ordinary function application plus automatic argument selection, not a global dependency resolver. Use `lib.callPackageWith customScope` for a deliberate custom scope. `lib.makeScope` and `newScope` support mutually dependent package families, but a small package collection often needs only a plain attribute set.

### Common misconceptions

- **“Nixpkgs is just a catalog.”** It is a function-generated package set with policies, platform predicates, and dependencies.
- **“`callPackage` downloads dependencies.”** It selects Nix values by argument name; realization happens later.
- **“Every function argument becomes a runtime dependency.”** Dependency propagation depends on how the value is used and which derivation input class contains it.
- **“Importing Nixpkgs repeatedly is harmless.”** It can slow evaluation and produce inconsistent configurations.

### Recap

Import Nixpkgs once per intentional package-set configuration. Write dependency-explicit package functions, let `callPackage` wire defaults, and override only where composition requires it.

### Exercises

1. Package a tiny executable with a `callPackage`-friendly function.
2. Override one dependency at the call site.
3. Find the relevant `lib` functions for version comparison and recursive attribute merging.
4. Compare package identities from two imports configured with different overlays.

### Official links

- [Nixpkgs manual](https://nixos.org/manual/nixpkgs/stable/)
- [`callPackage` design pattern](https://nix.dev/tutorials/callpackage.html)
- [Nixpkgs library](https://nixos.org/manual/nixpkgs/stable/#chap-functions)
- [Nixpkgs repository](https://github.com/NixOS/nixpkgs)

## Chapter 2: `stdenv`, Phases, Hooks, and Inputs

**Platforms:** `[Linux]` `[macOS]`

### Objectives

- Trace a `stdenv.mkDerivation` build through its phases.
- Customize phases without discarding setup hooks.
- Classify dependencies across build, host, and target platforms.

### The generic builder

`stdenv.mkDerivation` wraps `builtins.derivation` with a shell-based generic builder, compiler toolchain, standard environment, and phase protocol. The usual phases are:

1. `unpackPhase`
2. `patchPhase`
3. `configurePhase`
4. `buildPhase`
5. `checkPhase` when enabled
6. `installPhase`
7. `fixupPhase`
8. `installCheckPhase` when enabled
9. `distPhase` when requested

`prePhases`, `preConfigurePhases`, and related controls can add phases, while `preConfigure`, `postInstall`, and similar attributes add shell fragments around one phase.

```nix
stdenv.mkDerivation {
  pname = "greeter";
  version = "1.0";
  src = ./.;

  nativeBuildInputs = [ pkg-config makeWrapper ];
  buildInputs = [ openssl ];

  postPatch = ''
    substituteInPlace src/config.h \
      --replace-fail "/usr/bin/env" "${coreutils}/bin/env"
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ./greeter --self-test
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 greeter "$out/bin/greeter"
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/greeter" \
      --prefix PATH : ${lib.makeBinPath [ curl ]}
  '';
}
```

Custom phases should call `runHook preX` and `runHook postX`; otherwise setup hooks contributed by dependencies may silently stop working. Prefer build-system helpers (`cmake`, Meson, Python builders, Rust helpers) and flags such as `configureFlags` over replacing whole phases.

### Dependency classes

Cross compilation gives the input names precise meaning:

- `depsBuildBuild`: runs on build, produces for build.
- `nativeBuildInputs` (`depsBuildHost`): runs on build, produces for host; compilers, generators, `pkg-config`.
- `depsBuildTarget`: runs on build, produces for target; uncommon compiler-building tools.
- `depsHostHost`: runs on host, produces for host; uncommon native helpers.
- `buildInputs` (`depsHostTarget`): runs on host, produces for target; normal linked libraries.
- `depsTargetTarget`: runs on target, produces for target; uncommon.

In native builds build = host = target, so mistakes can stay hidden. Put tools executed during the build in `nativeBuildInputs`; put linked libraries in `buildInputs`. `propagatedBuildInputs` exposes dependencies to downstream consumers and should be used only when the consumer genuinely needs them, such as language import closure or public headers.

Setup hooks are scripts sourced by the generic builder when an input appears in the relevant dependency class. They can extend flags, register additional phases, or transform outputs. Examples include `pkg-config`, CMake hooks, wrapping hooks, and desktop-file hooks.

### Common misconceptions

- **“Phase order is arbitrary shell execution.”** The generic builder implements an extensible protocol with hooks.
- **“Everything goes in `buildInputs`.”** Build tools and target libraries differ, especially under cross compilation.
- **“Overriding a phase is safer than flags.”** It often drops upstream defaults and setup-hook behavior.
- **“Propagated inputs are more reliable.”** Over-propagation bloats closures and hides undeclared dependencies.

### Recap

Use the generic phase protocol, preserve hooks, and classify dependencies by where they run and what they produce. Native builds are not enough to validate that classification.

### Exercises

1. Add a test phase that preserves pre/post hooks.
2. Move a build-time generator from `buildInputs` to `nativeBuildInputs`.
3. Inspect `$NIX_BUILD_TOP`, `$out`, and phase variables with `nix develop`.
4. Explain each platform role for a compiler that builds firmware.

### Official links

- [Nixpkgs `stdenv`](https://nixos.org/manual/nixpkgs/stable/#chap-stdenv)
- [Phases](https://nixos.org/manual/nixpkgs/stable/#sec-stdenv-phases)
- [Dependency categories](https://nixos.org/manual/nixpkgs/stable/#ssec-stdenv-dependencies)
- [Setup hooks](https://nixos.org/manual/nixpkgs/stable/#ssec-setup-hooks)

## Chapter 3: Sources, Patches, Wrappers, and Quality

**Platforms:** `[Linux]` `[macOS]`

### Objectives

- Fetch immutable source inputs correctly.
- Apply patches and substitutions at the right phase.
- Wrap programs without introducing host-state assumptions.
- Provide useful metadata and tests.

### Fixed-output fetchers

Prefer fetchers that express source identity and verify content:

```nix
src = fetchFromGitHub {
  owner = "acme";
  repo = "tool";
  rev = "v${version}";
  hash = "sha256-...";
  fetchSubmodules = true;
};
```

Common fetchers include `fetchurl`, `fetchzip`, `fetchFromGitHub`,
`fetchFromGitLab`, `fetchgit`, `fetchhg`, and `fetchsvn`. Use a full immutable
revision rather than a branch. Hashes verify the fetcher's declared output:
`fetchurl` normally hashes the downloaded file directly, while unpacking and
tree fetchers generally use recursive/NAR hashing. They are not signatures and
do not establish publisher identity. Prefer SRI hashes (`sha256-...`).
`lib.fakeHash` can reveal an expected hash during packaging, but must never
remain in committed production expressions.

Language-specific fetchers may construct dependency sources: Cargo hashes or lock files, Go module vendors, npm lock-driven caches, Python package indexes, and Hackage sources. Their network access must become declared, hash-checked inputs; builds themselves should not depend on live package registries.

### Patching and substitution

Use `patches = [ ./fix-path.patch ];` for standard patches. Use `postPatch` for generated changes and `substituteInPlace` for deterministic textual substitutions. `substituteAll` can replace `@variable@` placeholders using derivation attributes.

Never patch binaries or scripts merely to change shebangs when hooks such as `patchShebangs` already cover the need. Avoid embedding `/usr`, `/opt`, or Homebrew paths. Reference store paths or create wrappers.

### Wrapping executables

`makeWrapper` and `wrapGAppsHook` produce launchers that supply environment expected at runtime:

```nix
nativeBuildInputs = [ makeWrapper ];

postInstall = ''
  wrapProgram "$out/bin/acme" \
    --prefix PATH : ${lib.makeBinPath [ git openssh ]} \
    --set-default ACME_DATA "$out/share/acme"
'';
```

Use `--prefix` when preserving user values is appropriate and `--set` only for intentional replacement. Wrapping is not a substitute for fixing linked-library resolution. On ELF systems, Nix fixup hooks commonly use RPATH/patchelf behavior; Darwin uses Mach-O install names and corresponding hooks.

### Metadata and tests

Useful `meta` includes `description`, `longDescription`, `homepage`, `changelog`, `license`, `maintainers`, `platforms`, `badPlatforms`, `mainProgram`, and `broken`. Metadata guides users and evaluation policy; it does not alter the artifact unless tooling consumes it.

Test at several levels:

```nix
doCheck = true;         # upstream tests during build
doInstallCheck = true;  # tests against installed output

passthru.tests = {
  version = testers.testVersion { package = finalAttrs.finalPackage; };
};
```

`passthru.tests` allows package-specific checks without always making every package build run them. NixOS VM tests belong in integration coverage. Avoid tests that require unrestricted internet or nondeterministic external services.

### Common misconceptions

- **“A content hash proves the source author.”** It proves content equality with the declared hash, not authorship.
- **“Using a tag is pinned.”** Tags can move; use the resolved commit when immutability matters.
- **“Wrappers automatically propagate to library users.”** They affect launched programs, not linking or import semantics.
- **“`meta.broken` causes a runtime warning.”** It normally prevents evaluation/build under policy unless explicitly allowed.

### Recap

Fetch immutable content with verified hashes, patch deterministically, wrap only runtime environment needs, and combine upstream, installed-output, and integration tests.

### Exercises

1. Package a release tarball with `fetchurl` and an SRI hash.
2. Replace an FHS path using `substituteInPlace`.
3. Wrap an executable with a runtime `PATH` dependency, then inspect the wrapper.
4. Add `testVersion` under `passthru.tests`.

### Official links

- [Nixpkgs fetchers](https://nixos.org/manual/nixpkgs/stable/#chap-pkgs-fetchers)
- [Patches and substitutions](https://nixos.org/manual/nixpkgs/stable/#ssec-patch-phase)
- [Wrapper hooks](https://nixos.org/manual/nixpkgs/stable/#ssec-setup-hooks)
- [Package metadata](https://nixos.org/manual/nixpkgs/stable/#chap-meta)
- [Nixpkgs tests](https://nixos.org/manual/nixpkgs/stable/#chap-testers)

## Chapter 4: Language Ecosystems

**Platforms:** `[Linux]` `[macOS]`

### Objectives

- Choose ecosystem-specific builders instead of reproducing package-manager behavior.
- Keep dependency resolution offline and pinned.
- Distinguish applications, libraries, and development environments.

### Python

Use the package set for the intended interpreter and PEP 517-aware builders:

```nix
python3Packages.buildPythonApplication {
  pname = "acme";
  version = "1.0";
  pyproject = true;
  src = ./.;
  build-system = with python3Packages; [ setuptools ];
  dependencies = with python3Packages; [ requests ];
  nativeCheckInputs = with python3Packages; [ pytestCheckHook ];
  pythonImportsCheck = [ "acme" ];
}
```

Use `buildPythonPackage` for importable libraries and `buildPythonApplication` for commands. Prefer `pyproject = true`/the currently documented format style for the Nixpkgs revision in use. `python.withPackages` creates an interpreter environment; it does not package your project.

### Rust

`rustPlatform.buildRustPackage` builds Cargo projects. Pin dependencies through `Cargo.lock` and use the revision-appropriate `cargoHash`, `cargoLock`, or vendoring interface. Git dependencies may need explicit output hashes. Build scripts are native tools; linked libraries belong in the appropriate host/target classes.

```nix
rustPlatform.buildRustPackage {
  pname = "acme";
  version = "1.0";
  src = ./.;
  cargoHash = "sha256-...";
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];
}
```

### Go, Node.js, and other ecosystems

`buildGoModule` vendors module dependencies using `vendorHash`. Node.js packaging has several Nixpkgs tools whose recommendation changes with ecosystem and Nixpkgs release; use lock files and the current Nixpkgs manual rather than fetching from npm in a build. Similar rules apply to Maven/Gradle, Ruby/Bundler, Haskell/Cabal, and OCaml: use the maintained ecosystem infrastructure, commit upstream lock data where applicable, and convert resolution into fixed Nix inputs.

Development shells can include mutable package-manager workflows for authoring, but a release derivation must work in the sandbox without undeclared network access. Keep “developer convenience environment” distinct from “reproducible package.”

### Common misconceptions

- **“A lock file alone makes an offline Nix build.”** Nix still needs a declared method to fetch and hash every dependency.
- **“`pip install` or `npm install` in `buildPhase` is normal.”** Network resolution violates sandboxed, reproducible builds.
- **“One interpreter package set can freely mix with another.”** Native extensions and package identities must match the chosen interpreter.
- **“A dev shell is the package.”** Shells supply tools; derivations define distributable outputs.

### Recap

Use Nixpkgs’ ecosystem builders, translate language lock data into fixed inputs, and test actual imports or executables. Consult the manual for the pinned Nixpkgs revision because helper interfaces evolve.

### Exercises

1. Package a Python project and add an import check.
2. Package a Cargo project from its lock file.
3. Explain why a successful network-enabled dev shell build may fail in the Nix sandbox.
4. Compare an application derivation with an interpreter/environment composition.

### Official links

- [Python](https://nixos.org/manual/nixpkgs/stable/#python)
- [Rust](https://nixos.org/manual/nixpkgs/stable/#rust)
- [Go](https://nixos.org/manual/nixpkgs/stable/#sec-language-go)
- [Node.js](https://nixos.org/manual/nixpkgs/stable/#language-javascript)
- [Haskell](https://nixos.org/manual/nixpkgs/stable/#haskell)

## Chapter 5: Overrides, Overlays, Configuration, and Cross Compilation

**Platforms:** `[Linux]` `[macOS]` `[Cross]`

### Objectives

- Select the narrowest package customization mechanism.
- Write overlays using `final` and `prev` safely.
- Distinguish Nixpkgs configuration from package overrides.
- Build and reason about cross package sets.

### Four customization layers

Function packages returned through `callPackage` often support `override`:

```nix
foo.override {
  enableBar = true;
  bar = pkgs.bar_2;
}
```

Derivations created with overridable builders commonly support `overrideAttrs`:

```nix
foo.overrideAttrs (finalAttrs: previousAttrs: {
  version = "1.1";
  src = fetchurl {
    url = "https://example.invalid/foo-${finalAttrs.version}.tar.gz";
    hash = "sha256-...";
  };
  patches = (previousAttrs.patches or []) ++ [ ./local-fix.patch ];
})
```

Use `override` to change function arguments and `overrideAttrs` to change derivation attributes. Prefer the two-argument form and preserve prior list values intentionally.

An overlay changes a package set:

```nix
final: prev: {
  foo = prev.foo.overrideAttrs {
    patches = (prev.foo.patches or []) ++ [ ./fix.patch ];
  };
  myTool = final.callPackage ./my-tool.nix { };
}
```

Read existing packages from `prev`; use `final` for dependencies that should see the completed overlay stack. Referring to `final.foo` while defining `foo` creates recursion. Overlay order matters.

Nixpkgs `config` controls policy and package options, such as permitted licenses or package-specific settings:

```nix
import nixpkgs {
  inherit system;
  config = {
    allowUnfreePredicate = pkg:
      builtins.elem (nixpkgs.lib.getName pkg) [ "vscode" ];
  };
}
```

Environment variables such as `NIXPKGS_ALLOW_UNFREE=1` are impure conveniences and require `--impure` in pure flake evaluation. Prefer explicit project policy.

### Cross compilation

Nix names three platforms:

- **build:** where compilation runs;
- **host:** where the produced package runs;
- **target:** what a compiler produced by the build will itself produce code for.

Create a cross package set:

```nix
pkgsCross = import nixpkgs {
  localSystem = "x86_64-linux";
  crossSystem = "aarch64-linux";
};

armHello = pkgsCross.hello;
```

Nixpkgs also exposes curated `pkgsCross` targets. Do not set only a `system`
string and assume cross compilation occurred. Packages must correctly classify
tools and libraries, and upstream build systems must honor cross parameters.
Tests that execute host-platform binaries cannot run directly on the build
machine without emulation or a remote builder. For packages that themselves
produce compilers, tests of generated target-platform code add a separate
target concern.

For a cross package set:

- `buildPackages` contains tools runnable on the build platform.
- the ordinary package namespace generally produces host-platform artifacts;
- `targetPackages` matters mainly when building compilers.

Platform predicates in `stdenv.buildPlatform`, `hostPlatform`, and `targetPlatform` are more reliable than ad hoc string matching.

### Common misconceptions

- **“An overlay is the right way to change one local package.”** A direct `overrideAttrs` is simpler when no package-set-wide rewiring is needed.
- **“`final` and `prev` are interchangeable.”** They encode fixed-point stage and dependency intent.
- **“Unfree packages cannot be built with Nix.”** Nixpkgs policy blocks them by default; explicit configuration can permit selected packages, subject to license obligations.
- **“Cross compilation means setting `system` to the target.”** That describes a native package set evaluated for another system, not where compilation runs.

### Recap

Use function overrides for arguments, attribute overrides for derivations, overlays for package-set-wide composition, and configuration for policy. Cross builds require explicit build/host/target reasoning and correctly classified dependencies.

### Exercises

1. Change a package version with `overrideAttrs` while preserving patches.
2. Write an overlay that adds a package and changes its dependency.
3. Permit exactly one unfree package by name.
4. Cross-build a simple static executable and inspect its file format.
5. Identify which cross-built test phases can execute locally.

### Official links

- [Overriding packages](https://nixos.org/manual/nixpkgs/stable/#chap-overrides)
- [Overlays](https://nixos.org/manual/nixpkgs/stable/#chap-overlays)
- [Nixpkgs configuration](https://nixos.org/manual/nixpkgs/stable/#chap-packageconfig)
- [Cross compilation](https://nixos.org/manual/nixpkgs/stable/#chap-cross)
