# Advanced Evaluation

**Platforms:** `[Linux]` `[macOS]` `[Evaluator]`

## Objectives

- recognize import-from-derivation and its evaluation/build boundary;
- control source-tree identity with explicit filtering;
- distinguish pure and restricted evaluation;
- understand evaluator caches and evaluation stores; and
- profile evaluation before optimizing it.

The runnable expressions for this chapter live in
`examples/advanced-evaluation`. Safe examples have a `safe-` prefix.
Expressions prefixed `intentional-` demonstrate impurity, IFD, or denial and
are not connected to the flake's packages or checks.

## Import from derivation (IFD)

Import from derivation occurs when evaluation needs to import a file whose path
is a derivation output:

```nix
generated = pkgs.runCommand "generated.nix" { } ''
  echo '{ answer = 42; }' > "$out"
'';
result = import generated;
```

Evaluation must pause, realize `generated`, then continue by parsing its output.
This couples evaluation to building, reduces parallel planning, may require a
store or builder during evaluation, and is disabled by many evaluators and
services. A derivation merely appearing as a package is not IFD; forcing its
output as evaluator input is.

Prefer generating Nix data ahead of time and committing it, generating JSON
outside evaluation and passing it as an explicit source input, or representing
the transformation directly in Nix. If IFD is unavoidable, isolate and
document it, keep the generator small, pin every input, and ensure CI explicitly
tests an evaluator that permits it.

The intentional example requires legacy `<nixpkgs>` lookup and IFD:

```console
nix-instantiate --eval --strict --impure \
  examples/advanced-evaluation/intentional-ifd.nix
```

It can build a derivation during evaluation. It is intentionally absent from
default packages and automatic checks.

## Source filtering

Passing `./.` to a derivation copies the source path selected by Nix. Irrelevant
files can change that store path, invalidate builds, enlarge uploads, and force
expensive tree traversal. `builtins.path` gives the copied source an explicit
name and filter:

```nix
builtins.path {
  path = ./fixtures;
  name = "filtered-source";
  filter = path: type:
    type == "directory" || builtins.match ".*[.]txt" (baseNameOf path) != null;
}
```

A filter receives a path and type. Returning `false` for a directory prunes its
whole subtree, so keep directory policy explicit. Avoid using ambient state or
reading file contents in a hot filter. In production, libraries such as
Nixpkgs' `lib.cleanSourceWith` can compose filters, but inspect their semantics
instead of assuming `.gitignore` is applied.

Run the self-contained example:

```console
nix eval --file examples/advanced-evaluation/safe-source-filter.nix --json
```

Only the selected files appear in the resulting store source. Filtering is an
input-boundary decision, not a secret-hiding mechanism; secrets should never be
inside the source tree passed to Nix.

## Pure and restricted evaluation

Pure evaluation rejects ambient inputs such as `<nixpkgs>` lookup through
`NIX_PATH`, `builtins.getEnv`, `builtins.currentSystem`, unlocked flake
references, and arbitrary absolute paths outside declared inputs. Flake
commands evaluate purely by default. `--impure` restores ambient access and
should be a deliberate diagnostic or compatibility choice, not dependency
injection.

Restricted evaluation is a policy boundary that limits filesystem and network
access available to the evaluator. Exact allowed paths and URI behavior depend
on Nix version and configuration. It is useful for evaluating less-trusted
expressions, but it is not a complete sandbox for builds or for programs that
you later run.

```console
nix-instantiate --eval --strict \
  examples/advanced-evaluation/safe-pure-data.nix

# INTENTIONAL impurity: output depends on ADVANCED_EVAL_MESSAGE.
ADVANCED_EVAL_MESSAGE=hello nix-instantiate --eval --strict --impure \
  examples/advanced-evaluation/intentional-impure-env.nix

# INTENTIONAL denial: restricted evaluation should reject the file read.
nix-instantiate --eval --strict --restrict-eval \
  examples/advanced-evaluation/intentional-restricted-read.nix
```

`builtins.tryEval` catches evaluation failure only to weak-head normal form; it
does not make denied access acceptable and may not force nested values.

## Evaluation caches and stores

The flake evaluation cache records results of eligible flake attribute
evaluation so repeated commands need not recompute them. Use
`--no-eval-cache` when diagnosing stale-looking results or measuring evaluator
work rather than cache hits. The cache is an optimization: correctness must not
depend on it, and impure evaluation is a poor cache key because ambient inputs
are not represented reliably.

Evaluation also performs store operations: adding source trees, reading valid
paths, or realizing IFD. By default evaluation and build planning normally use
the local store. Advanced commands can select an evaluation store separately
from the destination/build store (for example, using `--eval-store` where the
command supports it). This is useful with remote stores and CI, but any paths
needed across stores must be copied or substitutable, and IFD makes that
boundary more expensive. Store URLs and option support vary by Nix release;
consult `nix help-stores` and the command's `--help` before operational use.

Do not confuse three caches:

- the **evaluation cache** memoizes evaluator results;
- the **Nix store** retains source paths, derivations, and realized outputs;
- a **binary cache** substitutes serialized store objects across machines.

Deleting or bypassing one does not invalidate the others.

## Profiling evaluation

Measure a narrow attribute in a clean process and separate evaluation from
realization:

```console
/usr/bin/time -l nix eval --no-eval-cache \
  .#packages.x86_64-linux.default.drvPath
nix build --dry-run .#packages.x86_64-linux.default
```

On GNU systems use `/usr/bin/time -v`. Repeat measurements and compare the same
attribute and lock revision. `--strict` forces values and can expose hidden
cost, but it changes the workload.

Nix can emit evaluator profiles in builds that support the relevant
experimental/internal options. Because profile flags and formats have changed,
check the installed version first:

```console
nix eval --help | grep -i profile
nix --version
```

If available, collect a profile for one representative attribute and inspect
the hottest functions and source positions. Otherwise use wall time, maximum
resident memory, `NIX_SHOW_STATS=1` where supported, and controlled expression
changes. Typical wins are sharing Nixpkgs imports, avoiding repeated overlay
fixpoints, keeping output trees lazy, replacing repeated list concatenation,
and reducing broad `readDir` or source-filter traversal.

## Common misconceptions

- **“A generated derivation is always IFD.”** It becomes IFD only when evaluation consumes its realized output.
- **“Source filtering follows `.gitignore`.”** Only the chosen source mechanism and filter determine inclusion.
- **“Pure evaluation means builds are sandboxed.”** Evaluation purity and build sandboxing are different phases.
- **“Restricted evaluation makes arbitrary Nix safe.”** It narrows evaluator access; it does not secure later builds or runtime.
- **“The eval cache is the binary cache.”** They cache different objects at different phases.
- **“A faster second run proves an optimization.”** It may only demonstrate cache warming.

## Recap

Avoid IFD unless evaluation truly must consume generated data, filter source
trees at intentional boundaries, and use pure evaluation to make dependencies
explicit. Treat restricted evaluation, evaluation stores, and caches as
separate mechanisms, and profile a stable workload before changing code.

## Official links

- [Nix language import](https://nix.dev/manual/nix/latest/language/builtins.html#builtins-import)
- [`builtins.path`](https://nix.dev/manual/nix/latest/language/builtins.html#builtins-path)
- [Nix command common options](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix)
- [Nix store types](https://nix.dev/manual/nix/latest/store/types/)
- [Nix performance best practices](https://nix.dev/guides/best-practices.html)
