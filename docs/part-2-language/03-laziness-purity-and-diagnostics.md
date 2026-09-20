# 7. Laziness, Purity, and Diagnostics

## Objectives

By the end of this chapter, you will be able to:

- predict which expressions Nix evaluates;
- force values to weak head normal form or deeply;
- use assertions, errors, traces, `tryEval`, and `deepSeq`;
- separate evaluation purity, build isolation, and reproducibility.

## Nix Is Lazy

Nix evaluates expressions only as far as the requested result requires. Unused bindings are not evaluated:

```console
# nix eval --expr 'let broken = 1 / 0; in 42'
42
```

Collections are also lazy in their elements. Producing the outer list or set does not necessarily force every member:

```console
# nix eval --expr 'builtins.length [ (1 / 0) 2 3 ]'
3
```

`length` needs the list spine but not its first element. Selecting that element fails:

```console
# nix eval --expr 'builtins.elemAt [ (1 / 0) 2 3 ] 0'
error: division by zero
```

Laziness enables large package sets and recursive definitions but can delay failures far from their source.

## Weak and Deep Evaluation

Many operations evaluate only to **weak head normal form**: enough to know whether a value is a list, set, function, or scalar, without recursively forcing children.

`builtins.seq a b` evaluates `a` shallowly, then returns `b`:

```console
# nix eval --expr 'builtins.seq (1 + 1) 42'
42
# nix eval --expr 'builtins.seq [ (1 / 0) ] 42'
42
```

The second succeeds because forcing the list does not force its element.

`builtins.deepSeq a b` recursively forces `a`, then returns `b`:

```console
# nix eval --expr 'builtins.deepSeq { ok = 1; nested.bad = 1 / 0; } 42'
error: division by zero
```

Use deep forcing at validation boundaries, not indiscriminately across enormous package sets.

The CLI can force a printed value more completely:

```console
# nix eval --strict --expr '{ a = 1 + 1; b = [ 3 4 ]; }'
{ a = 2; b = [ 3 4 ]; }
```

## Explicit Errors and Assertions

Abort with a useful message:

```console
# nix eval --expr 'throw "configuration is missing a port"'
error: configuration is missing a port
```

`throw` is a built-in function that raises a catchable evaluation error;
`builtins.abort` is another terminating primitive, generally used for
unrecoverable errors.

Assertions validate a Boolean condition before returning a value:

```console
# nix eval --expr '
  let port = 8080;
  in assert port > 0 && port < 65536; "valid"'
"valid"
```

Add context when a complex operation fails:

```console
# nix eval --expr '
  builtins.addErrorContext "while validating service.port"
    (assert false; 42)'
error:
… while validating service.port
```

Error messages and formatting vary by Nix version, but the context should appear.

## Tracing Evaluation

`builtins.trace message value` prints a diagnostic and returns `value`:

```console
# nix eval --expr 'builtins.trace "computing answer" (6 * 7)'
trace: computing answer
42
```

Because evaluation is lazy, an unneeded trace does not run:

```console
# nix eval --expr 'let x = builtins.trace "unused" 1; in 42'
42
```

Trace output is for debugging, not a stable data channel. Avoid leaving noisy or secret-bearing traces in shared expressions.

## Catching Evaluation Failure with `tryEval`

`builtins.tryEval expression` returns a set with `success` and `value`:

```console
# nix eval --expr 'builtins.tryEval (1 / 0)'
{ success = false; value = false; }
# nix eval --expr 'builtins.tryEval (20 + 22)'
{ success = true; value = 42; }
```

`tryEval` evaluates shallowly. A nested failure can remain hidden:

```console
# nix eval --expr 'builtins.tryEval { bad = 1 / 0; }'
{ success = true; value = { bad = «error: division by zero»; }; }
```

Combine it with `deepSeq` to test the full structure:

```console
# nix eval --expr '
  let x = { bad = 1 / 0; };
  in builtins.tryEval (builtins.deepSeq x x)'
{ success = false; value = false; }
```

`tryEval` intentionally does not expose arbitrary exception details as a programmable string. Use error context and command diagnostics for human investigation.

## Purity Has Several Meanings

Keep these boundaries separate:

1. **Language-level functional style**: expressions tend to map explicit inputs to values.
2. **Pure evaluation mode**: restricts ambient inputs such as arbitrary filesystem paths and environment variables.
3. **Sandboxed realization**: constrains builder access to the host.
4. **Reproducible output**: repeated builds produce equivalent or identical results.

None automatically guarantees all the others. A pure evaluation may describe a builder that embeds timestamps. A sandboxed build can still be nondeterministic. An impure evaluation can happen to produce stable output.

## Infinite Recursion and Laziness

Recursive bindings are legal, but forcing a cycle that cannot produce a constructor fails:

```console
# nix eval --expr 'let x = x; in x'
error: infinite recursion encountered
```

Some recursive structures are productive because the outer constructor is available:

```console
# nix eval --expr 'let x = [ 1 ] ++ x; in builtins.elemAt x 0'
1
```

Do not use infinite structures casually: printing or deeply forcing one cannot terminate.

## Common Misconceptions

- **“If evaluation succeeds, every nested value is valid.”** Lazy children may still contain errors.
- **“`seq` validates a whole set.”** It forces only the outer value.
- **“`tryEval` catches every nested failure.”** Pair it with `deepSeq` when deep validation is required.
- **“Traces run in source order.”** They run when laziness demands their values.
- **“Pure evaluation guarantees reproducible binaries.”** It controls evaluation inputs, not every builder behavior.
- **“Assertions are type declarations.”** They are runtime evaluation checks.

## Recap

Laziness avoids unnecessary evaluation and supports huge recursive structures, but delays errors. `seq`, `deepSeq`, and `--strict` control forcing; assertions and contextual errors communicate invariants; traces reveal demanded computation; and `tryEval` converts shallow failure into data.

## Exercises

1. Construct a list with a failing third item. Show an operation that succeeds without forcing it and one that fails.
2. Compare `seq` and `deepSeq` on a nested failing attribute.
3. Write a port assertion that produces useful error context.
4. Use `trace` in an unused binding and explain the absent output.
5. Make `tryEval` report failure for an error nested three sets deep.

## Official Sources

- [Nix language: laziness](https://nix.dev/manual/nix/latest/language/)
- [`builtins.seq`](https://nix.dev/manual/nix/latest/language/builtins.html#builtins-seq)
- [`builtins.deepSeq`](https://nix.dev/manual/nix/latest/language/builtins.html#builtins-deepSeq)
- [`builtins.tryEval`](https://nix.dev/manual/nix/latest/language/builtins.html#builtins-tryEval)
- [Assertions](https://nix.dev/manual/nix/latest/language/constructs#assertions)
- [Evaluation settings](https://nix.dev/manual/nix/latest/command-ref/conf-file#evaluation-settings)
