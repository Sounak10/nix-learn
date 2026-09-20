# Nix Language and CLI Cheat Sheets

## Objectives

Use this appendix to recall common syntax and select modern or legacy commands deliberately. Confirm version-specific flags with `nix help`.

## Language

### Values and bindings

```nix
let
  name = "demo";
  numbers = [ 1 2 3 ];
  attrs = { enabled = true; count = 3; };
in {
  inherit name;
  doubled = map (x: x * 2) numbers;
  count = attrs.count or 0;
}
```

| Need | Form |
|---|---|
| Function | `x: x + 1` |
| Attrset function | `{ lib, pkgs, optional ? false }: ...` |
| Call | `f arg` or `f { inherit pkgs; }` |
| Dynamic attribute | `{ ${name} = value; }` |
| Merge attrsets | `a // b` (right side wins) |
| String interpolation | `"path: ${toString value}"` |
| Conditional list member | `lib.optional condition value` |
| Conditional attrset | `lib.optionalAttrs condition { ... }` |
| Assert | `assert condition; value` |
| Trace temporarily | `builtins.trace "message" value` |

Remember: `with` hides value origins, `rec` expands recursive scope, and `//` is shallow. Prefer explicit bindings when maintenance matters.

### Package expression skeleton

```nix
{ stdenv, lib, fetchFromGitHub }:

stdenv.mkDerivation (finalAttrs: {
  pname = "example";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "owner";
    repo = "example";
    rev = "v${finalAttrs.version}";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  meta = {
    description = "Example package";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
```

## CLI

### Evaluate and inspect

```console
$ nix eval .#value
$ nix eval --raw .#stringValue
$ nix eval --json .#structuredValue
$ nix repl
$ nix flake metadata
$ nix flake show
$ nix flake check
$ nix derivation show .#package
```

### Build and run

```console
$ nix build .#package
$ nix build .#package --no-link --print-out-paths
$ nix build .#package -L --show-trace
$ nix run nixpkgs#hello -- --help
$ nix shell nixpkgs#git nixpkgs#jq
$ nix develop
```

### Store and closure

```console
$ nix path-info .#package
$ nix path-info --recursive --closure-size .#package
$ nix why-depends .#package nixpkgs#dependency
$ nix copy --to ssh-ng://host .#package
$ nix store verify --all --check-contents
$ nix store gc
$ nix store diff-closures OLD NEW
```

### Profiles and flakes

```console
$ nix profile list
$ nix profile add nixpkgs#ripgrep
$ nix profile upgrade --all
$ nix profile rollback
$ nix flake lock
$ nix flake update
$ nix flake update input-name
```

`nix flake update` intentionally changes pins. Review `flake.lock` and test resulting closures before deployment.

### Useful legacy equivalents

| Purpose | Modern | Legacy |
|---|---|---|
| Build expression | `nix build` | `nix-build` |
| Evaluate | `nix eval` | `nix-instantiate --eval` |
| Show derivation | `nix derivation show` | `nix show-derivation` |
| Query references | `nix path-info --recursive` | `nix-store --query --requisites` |
| Copy closure | `nix copy` | `nix-copy-closure` |
| Collect garbage | `nix store gc` | `nix-collect-garbage` |

Legacy commands remain relevant in scripts and stable deployments. Do not mechanically replace them without checking output formats and semantics.

## Common misconceptions

- Whitespace separates function arguments; Nix does not use commas in lists or calls.
- Attribute selection (`a.b`) is not string concatenation.
- `nix shell` creates an environment; `nix develop` enters a development shell from a flake output.
- `nix run` runs an app; it does not install it into a profile.
- `--refresh` refreshes cache metadata; it is not the same as updating `flake.lock`.

## Recap

Keep language expressions explicit and lazy, use JSON output for automation, and choose commands based on whether you are evaluating, realizing, running, installing, or operating on the store.

## Exercises

1. Rewrite a `with pkgs;` expression using explicit package references.
2. Produce a package path without creating a `result` symlink.
3. Find both modern and legacy commands for a recursive closure query.
4. Update one flake input and inspect only its lock-file changes.

## Official links

- [Nix language](https://nix.dev/manual/nix/latest/language/)
- [Nix command reference](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix.html)
- [Nixpkgs standard environment](https://nixos.org/manual/nixpkgs/stable/#chap-stdenv)
- [Flake reference](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake.html)
