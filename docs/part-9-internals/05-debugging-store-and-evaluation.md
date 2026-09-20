# Debugging Store and Evaluation Problems

## Objectives

By the end of this chapter, you should be able to:

- choose between `nix repl`, logs, derivation inspection, and path queries;
- trace unexpected runtime dependencies;
- compare two store outputs; and
- isolate evaluation, build, substitution, and deployment failures.

## Start by naming the phase

Ask where the failure occurs:

1. **Parse/evaluate:** no derivation was produced.
2. **Plan/substitute:** Nix cannot locate or trust a result.
3. **Build:** the builder exited unsuccessfully.
4. **Register/copy:** verification, references, or store transfer failed.
5. **Run:** the realized program behaves incorrectly.

This classification prevents build flags from being applied to evaluator errors and avoids debugging the daemon when the application itself is failing.

## `nix repl`

Use the REPL to inspect values incrementally:

```console
$ nix repl
nix-repl> :lf .
nix-repl> outputs.packages.x86_64-linux
nix-repl> :p outputs.packages.x86_64-linux.default.meta
nix-repl> :t builtins.map
```

For a package set:

```console
$ nix repl --file '<nixpkgs>'
nix-repl> hello.drvPath
nix-repl> hello.meta.platforms
```

Avoid printing enormous recursive attrsets. Select one path and use `:p` only when forcing the value is intentional.

## Logs and derivations

```console
$ nix build .#package -L --show-trace
$ nix log .#package
$ nix log /nix/store/<hash>-name.drv
$ nix derivation show .#package
$ nix derivation show /nix/store/<hash>-name.drv
```

`-L` streams build logs; `nix log` retrieves recorded logs after the fact. `--show-trace` expands evaluator call traces and does not add shell tracing inside builders. To inspect a failed build directory, use `--keep-failed` when supported and read the reported path.

The older spelling `nix show-derivation` may still exist, but `nix derivation show` is the current command family.

## Paths, dependencies, and differences

```console
$ nix path-info .#package
$ nix path-info --json --recursive --closure-size .#package
$ nix why-depends .#package nixpkgs#openssl
$ nix-store --query --tree "$(nix build --no-link --print-out-paths .#package)"
$ nix store diff-closures /nix/var/nix/profiles/system-42-link /nix/var/nix/profiles/system-43-link
```

`nix why-depends A B` finds a reference path from A's closure to B. If the dependency is surprising, inspect wrappers, shebangs, RPATHs, pkg-config files, generated metadata, and copied build scripts.

`nix store diff-closures` compares versions and size contributions between closures. It is a closure-level summary, not a byte-for-byte directory diff. For reproducibility investigation, rebuild independently and use a specialized artifact diff tool after confirming NAR hashes differ.

Useful checks:

```console
$ nix store verify --all --check-contents
$ nix build .#package --rebuild
$ nix build .#package --no-substitute
$ nix build .#package --dry-run
```

`--no-substitute` changes provenance and cost; it is a diagnostic switch, not a routine fix.

## Common misconceptions

- **“`--show-trace` shows every command a builder ran.”** It shows Nix evaluator traces.
- **“No log means no build happened.”** The result may have been substituted, already valid, or logged elsewhere.
- **“`why-depends` explains semantic intent.”** It reports a registered reference chain, which can be accidental.
- **“Store diff compares file contents.”** `diff-closures` primarily summarizes closure package/version changes.
- **“Deleting the path fixes corruption.”** Direct deletion can desynchronize the database. Use supported repair or store deletion commands.

## Recap

First identify the failing phase. Use the REPL for values, logs for builder output, derivation JSON for recipes, `path-info` for closure facts, `why-depends` for reference chains, and `diff-closures` for generation or deployment changes.

## Exercises

1. Introduce an undefined variable and compare normal output with `--show-trace`.
2. Build a package, retrieve its log, and identify whether it was built or substituted.
3. Use `why-depends` to explain one large closure dependency.
4. Compare two system or profile generations with `diff-closures`.

## Official links

- [`nix repl`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-repl.html)
- [`nix log`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-log.html)
- [`nix derivation show`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-derivation-show.html)
- [`nix path-info`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-path-info.html)
- [`nix why-depends`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-why-depends.html)
- [`nix store diff-closures`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-store-diff-closures.html)
