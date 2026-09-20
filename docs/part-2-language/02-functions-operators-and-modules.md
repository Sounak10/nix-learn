# 6. Functions, Operators, and Imports

## Objectives

By the end of this chapter, you will be able to:

- define and call curried functions;
- destructure attribute arguments with defaults, `...`, and whole-set bindings;
- apply Nix's major operators with correct precedence;
- split expressions across files with `import`;
- reason about lexical scope and shadowing.

## Functions Have One Argument

A function is written `argument: body`:

```console
# nix eval --expr '(x: x + 1) 41'
42
```

Function application uses whitespace and binds tightly. Multi-argument functions are nested one-argument functions:

```console
# nix eval --expr 'let add = x: y: x + y; in add 20 22'
42
```

This allows partial application:

```console
# nix eval --expr 'let add = x: y: x + y; addTen = add 10; in addTen 32'
42
```

Parenthesize arguments that are themselves expressions or calls:

```console
# nix eval --expr 'builtins.toString (20 + 22)'
"42"
```

## Attribute-Set Patterns

Functions commonly accept named arguments:

```console
# nix eval --expr '({ name, greeting }: "${greeting}, ${name}!") \
    { name = "Ada"; greeting = "Hello"; }'
"Hello, Ada!"
```

Defaults use `?` inside the pattern:

```console
# nix eval --expr '({ name, punctuation ? "!" }: "${name}${punctuation}") \
    { name = "Nix"; }'
"Nix!"
```

Without `...`, unexpected attributes are errors. With `...`, extras are accepted:

```console
# nix eval --expr '({ x, ... }: x) { x = 42; ignored = true; }'
42
```

Bind the entire input set with `@`:

```console
# nix eval --expr '({ x, y ? 2, ... } @ args: \
    { sum = x + y; original = args; }) { x = 40; note = "kept"; }'
{ original = { note = "kept"; x = 40; }; sum = 42; }
```

The equivalent `args@{ x, ... }` form is also accepted. Notice that `args` is the original set; defaulted `y` is available as a local binding but is not inserted into `args`.

## Operators

Important operators include:

- arithmetic: `+`, `-`, `*`, `/`;
- comparison: `==`, `!=`, `<`, `<=`, `>`, `>=`;
- Boolean: `!`, `&&`, `||`, implication `->`;
- list concatenation: `++`;
- attribute-set update: `//`;
- attribute existence: `set ? path`;
- defaulted selection: `set.path or fallback`;
- function application by whitespace;
- pipeline operators `|>` and `<|` in Nix versions that support them.

Runnable examples:

```console
# nix eval --expr '[ (1 + 2 * 3) (true && !false) (false -> false) ]'
[ 7 true true ]
# nix eval --expr '({ a = 1; } // { a = 2; }).a'
2
# nix eval --expr '[ 1 2 ] ++ [ 3 ]'
[ 1 2 3 ]
```

Implication `a -> b` means `!a || b`. Do not confuse it with a function arrow; functions use `:`.

Because unary minus, subtraction, path syntax, function application, and attribute selection can interact, parenthesize when intent is not obvious. Consult the official precedence table instead of relying on another language's rules.

Recent Nix releases support pipe operators:

```console
# nix eval --expr '[ 1 2 3 ] |> map (x: x * 2)'
[ 2 4 6 ]
```

If an older Nix rejects that syntax, use `map (x: x * 2) [ 1 2 3 ]`. Check `nix --version`; syntax compatibility is determined before evaluation.

## Lexical Scope and Shadowing

Functions capture the lexical environment where they are defined:

```console
# nix eval --expr '
  let
    x = 10;
    addX = y: x + y;
  in
    let x = 100; in addX 32'
42
```

The inner `x` does not change the captured `x`. Function parameters and inner `let` bindings may shadow outer names, but duplicate names in the same binding set are errors.

`with` introduces lower-priority names: an existing lexical binding wins. This subtle rule is another reason to avoid broad `with` expressions.

## Imports

`import path` evaluates the Nix file at `path` and returns its value. It is an ordinary built-in operation, not a textual include and not a module system.

Create two temporary files inside Docker:

```console
# mkdir -p /tmp/nix-import
# printf '%s\n' '{ factor ? 2 }: x: x * factor' > /tmp/nix-import/multiply.nix
# printf '%s\n' \
    'let multiply = import ./multiply.nix { factor = 6; }; in multiply 7' \
    > /tmp/nix-import/default.nix
# nix eval --file /tmp/nix-import/default.nix
42
```

The imported file returns a function. The caller explicitly supplies its arguments. Relative import paths resolve relative to the importing file.

For a directory, `import ./directory` conventionally resolves its `default.nix`. Explicit filenames are often clearer. `import` does not automatically pin remote dependencies, merge configurations, or isolate scope.

## Pure Evaluation

Pure evaluation restricts access to undeclared environmental inputs. Flake evaluation is pure by default; direct `nix eval --expr` workflows may permit more ambient access.

For example, reading an environment variable is impure:

```console
# TOKEN=secret nix eval --impure --raw \
    --expr 'builtins.getEnv "TOKEN"'
secret
```

Purity makes evaluation results less dependent on current directories, environment variables, lookup paths, or arbitrary host files. It is distinct from sandboxing, which constrains build execution.

## Common Misconceptions

- **“Nix has native two-argument functions.”** `x: y: ...` is a function returning a function.
- **“`...` supplies missing values.”** It accepts extra attributes; defaults supply missing ones.
- **“The `@` binding includes defaults.”** It names the original argument set.
- **“`import` pastes source code.”** It evaluates another file and returns its value.
- **“Pure evaluation means sandboxed builds.”** Evaluation purity and build sandboxing are separate controls.
- **“`->` defines a function.”** It is Boolean implication.

## Recap

Nix functions take one argument and commonly destructure attribute sets. Patterns make APIs explicit through required names, defaults, extras, and whole-set bindings. Operators compose values, imports compose files, and lexical scope determines name resolution.

## Exercises

1. Write a curried `volume` function and partially apply one dimension.
2. Define a pattern function with one required argument, one default, and accepted extras.
3. Show that a defaulted pattern value does not appear in the `@`-bound original set.
4. Split a list-transforming function and its caller into two temporary `.nix` files.
5. Rewrite `a -> b` using only `!` and `||`, then test all four Boolean combinations.

## Official Sources

- [Functions](https://nix.dev/manual/nix/latest/language/constructs#functions)
- [Function arguments](https://nix.dev/manual/nix/latest/language/constructs#functions)
- [Operator precedence](https://nix.dev/manual/nix/latest/language/operators)
- [`import`](https://nix.dev/manual/nix/latest/language/builtins.html#builtins-import)
- [Pure and restricted evaluation](https://nix.dev/manual/nix/latest/command-ref/conf-file#conf-pure-eval)
