# 8. Derivations, Evaluation, and Realization

## Objectives

By the end of this chapter, you will be able to:

- distinguish evaluation from realization;
- read the major fields of a derivation;
- inspect `.drv` files and predicted outputs;
- explain the builder contract and multiple outputs.

## From Expression to Output

A build commonly passes through these stages:

1. Nix parses and evaluates language expressions.
2. Evaluation produces a **derivation** value: a build recipe.
3. Nix serializes that recipe as a `.drv` store object.
4. Realization obtains each requested output, by substitution or local building.
5. Successful outputs are registered as store objects with references and metadata.

Evaluation and realization are deliberately separate. This command evaluates arithmetic:

```console
# nix eval --expr '6 * 7'
42
```

This command evaluates the `hello` package expression and realizes its output:

```console
# nix build nixpkgs#hello --no-link
```

If a trusted substituter has the requested output, realization downloads it. “Realize” therefore does not necessarily mean “compile locally.”

## A Minimal Derivation

`builtins.derivation` is the primitive interface. In the official Linux container:

```console
# cat >/tmp/minimal.nix <<'EOF'
let
  system = builtins.currentSystem;
in builtins.derivation {
  name = "book-greeting";
  inherit system;
  builder = "/bin/sh";
  args = [ "-c" "printf '%s\n' 'hello from a builder' > \"$out\"" ];
}
EOF
# nix build --impure --file /tmp/minimal.nix
# cat result
hello from a builder
```

The result is a regular file because the builder wrote a file to `$out`. Packages usually create a directory and populate `$out/bin`, `$out/lib`, and related paths.

This pedagogical derivation uses host `/bin/sh`, so it is impure and may not work under stricter sandbox or non-Linux setups. Production expressions pass a shell from the store or use higher-level helpers from Nixpkgs. The example's purpose is to expose the primitive contract.

## What Evaluation Produces

Inspect the derivation path without realizing the output:

```console
# nix path-info --derivation --file /tmp/minimal.nix
/nix/store/...-book-greeting.drv
```

Ask for the output path:

```console
# nix eval --impure --raw --file /tmp/minimal.nix --apply 'd: d.outPath'
/nix/store/...-book-greeting
```

The output path can be known before its contents exist for traditional input-addressed derivations. Knowing a path is not proof that it has been realized.

Use a well-supported Nixpkgs derivation to inspect JSON:

```console
# nix derivation show nixpkgs#hello
```

The JSON includes:

- `system`: required execution platform;
- `builder`: executable Nix launches;
- `args`: arguments passed to it;
- `env`: environment variables;
- `inputDrvs`: input derivations and selected outputs;
- `inputSrcs`: source store paths;
- `outputs`: declared output names and addressing metadata.

Treat the exact JSON schema and CLI output as versioned interfaces; inspect your installed command's help when automating.

## The Builder Contract

For each local build, Nix prepares a controlled environment and runs:

```text
builder arg1 arg2 ...
```

It supplies environment variables including each output path (`out` for the conventional default output). The builder must create the declared outputs, return success, and avoid writing undeclared results into the store.

Builders should not assume a normal login environment. Nix clears or sets much of the environment, uses a temporary build directory, and may restrict network and filesystem access. Higher-level Nixpkgs utilities add phases such as unpack, patch, configure, build, check, and install; those phases are conventions implemented by builder scripts, not fields intrinsic to the derivation primitive.

## Multiple Outputs

A derivation can declare several outputs:

```nix
builtins.derivation {
  name = "split-example";
  system = builtins.currentSystem;
  builder = "/bin/sh";
  outputs = [ "out" "dev" ];
  args = [ "-c" ''
    mkdir -p "$out/bin" "$dev/include"
    printf executable > "$out/bin/example"
    printf header > "$dev/include/example.h"
  '' ];
}
```

Splitting development files from runtime files can reduce runtime closures. Each output is a separate store path and can have different references.

## Derivation Values and Coercion

A derivation value behaves like an attribute set with fields such as `outPath`, `drvPath`, `outputName`, and declared attributes. In string contexts, it normally coerces to its default output path and carries string context so Nix can track the dependency.

That convenience can hide dependencies:

```nix
"tool lives at ${someDerivation}/bin/tool"
```

This is not merely formatting. It introduces a store-path context that can become an input or runtime reference depending on where the string is used.

## High-Level Package Functions

Real packages generally use Nixpkgs helpers such as `stdenv.mkDerivation`, language-specific builders, or fetchers. These helpers ultimately produce derivations while supplying portable tools, standard phases, platform logic, and policy.

Learning `builtins.derivation` explains the machine model; it is not a recommendation to reimplement Nixpkgs packaging infrastructure.

## Common Misconceptions

- **“Evaluation runs the compiler.”** It computes the recipe; realization obtains outputs.
- **“Realization always builds locally.”** A substituter may provide the output.
- **“A `.drv` contains source and binaries.”** It serializes a recipe and references inputs.
- **“Knowing `outPath` means the output exists.”** Traditional output paths can be predicted before realization.
- **“Configure/build/install phases are built into Nix.”** They are higher-level builder conventions.
- **“A derivation is limited to one output.”** Multiple named outputs are supported.

## Recap

Evaluation turns Nix expressions into values and derivations. `.drv` objects encode builders, arguments, environments, inputs, platforms, and outputs. Realization then substitutes or executes the recipe, and successful outputs become registered store objects.

## Exercises

1. Evaluate the minimal derivation's `drvPath` and `outPath`.
2. Delete `result`, rebuild with `--no-link`, and explain what changed.
3. Inspect `nixpkgs#hello` with `nix derivation show`; identify builder, system, and inputs.
4. Modify the temporary derivation to create a directory containing two files.
5. Explain why string interpolation of a derivation can affect dependencies.

## Official Sources

- [Derivations](https://nix.dev/manual/nix/latest/language/derivations)
- [`builtins.derivation`](https://nix.dev/manual/nix/latest/language/derivations#derivation)
- [Derivation store objects](https://nix.dev/manual/nix/latest/store/derivation/)
- [`nix derivation show`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-derivation-show)
- [Nixpkgs `stdenv`](https://nixos.org/manual/nixpkgs/stable/#chap-stdenv)
