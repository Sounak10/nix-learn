# 5. Values, Collections, and Composition

## Objectives

By the end of this chapter, you will be able to:

- write every fundamental Nix value;
- use strings, interpolation, paths, lists, and attribute sets correctly;
- compose scopes with `let`, `inherit`, `rec`, and `with`;
- select, test, merge, and update attributes.

## Evaluating Small Expressions

Use the REPL interactively or `nix eval` in scripts:

```console
# nix repl
nix-repl> 2 * 21
42
nix-repl> :q
```

For repeatable examples:

```console
# nix eval --expr '2 * 21'
42
```

Nix source files conventionally end in `.nix`, but this chapter can be completed without creating one.

## Atomic Values

Nix has integers, floating-point numbers, Booleans, and `null`:

```console
# nix eval --expr '{ i = -7; f = 2.5; yes = true; no = false; empty = null; }'
{ empty = null; f = 2.500000; i = -7; no = false; yes = true; }
```

There is no implicit truthiness: conditions must evaluate to Booleans.

```console
# nix eval --expr 'if 3 > 2 then "yes" else "no"'
"yes"
```

## Strings and Indented Strings

Double-quoted strings support escapes and interpolation:

```console
# nix eval --raw --expr '"line one\n${toString (6 * 7)}\n"'
line one
42
```

Indented strings use two single quotes and remove common indentation:

```console
# nix eval --raw --expr "''\
    first
      second
  ''"
first
  second
```

Inside an indented string, `''${` produces a literal `${`, and `'''` can represent two single quotes according to the language's escaping rules. Prefer testing nontrivial shell snippets because Nix interpolation and shell interpolation can collide.

Strings may carry hidden **string context** recording referenced store paths. Interpolating a derivation into a string can therefore create dependency information, not just visible text.

## Paths and URLs

A path literal is a distinct value:

```console
# cd /tmp
# nix eval --expr './.'
/tmp
# nix eval --expr 'builtins.typeOf ./.'
"path"
```

Relative paths resolve relative to the file containing the expression, or the current context for command-line expressions. Interpolating a path into a string can copy it into the store when required by a build expression.

Angle-bracket lookup paths such as `<nixpkgs>` depend on `NIX_PATH` and are less explicit than pinned inputs:

```nix
import <nixpkgs> {}
```

Nix historically has unquoted URL literals in parts of its grammar. Quote URLs:

```console
# nix eval --expr '"https://example.org/archive.tar.gz"'
"https://example.org/archive.tar.gz"
```

Quoting avoids parser ambiguity and makes the value plainly a string. Fetching a URL is a separate operation; a URL string does not fetch anything.

## Lists

Lists are whitespace-separated and heterogeneous:

```console
# nix eval --expr '[ 1 "two" true [ 3 ] ]'
[ 1 "two" true [ 3 ] ]
```

Parenthesize function calls inside lists:

```console
# nix eval --expr '[ (builtins.toString 1) (builtins.toString 2) ]'
[ "1" "2" ]
```

Useful operations:

```console
# nix eval --expr 'map (x: x * x) [ 1 2 3 4 ]'
[ 1 4 9 16 ]
# nix eval --expr '[ 1 2 ] ++ [ 3 4 ]'
[ 1 2 3 4 ]
```

Commas are not list separators. `[ 1, 2 ]` is invalid.

## Attribute Sets

An attribute set maps names to values:

```console
# nix eval --expr '{ name = "Ada"; nested.answer = 42; enabled = true; }'
{ enabled = true; name = "Ada"; nested = { answer = 42; }; }
```

Select attributes, provide a fallback, and test membership:

```console
# nix eval --expr 'let x = { a = 1; }; in [ x.a (x.b or 9) (x ? a) ]'
[ 1 9 true ]
```

Dynamic attribute names use interpolation:

```console
# nix eval --expr 'let key = "answer"; in { ${key} = 42; }'
{ answer = 42; }
```

The update operator is shallow:

```console
# nix eval --expr '{ a = 1; nested.x = 1; } // { b = 2; nested.y = 2; }'
{ a = 1; b = 2; nested = { y = 2; }; }
```

The right-hand `nested` replaces the left-hand `nested`; this is not a recursive merge.

## `let`, `inherit`, `rec`, and `with`

`let ... in ...` introduces lexical bindings. Bindings are mutually recursive:

```console
# nix eval --expr 'let a = b + 1; b = 41; in a'
42
```

`inherit` copies names without repeating assignments:

```console
# nix eval --expr 'let name = "Ada"; age = 36; in { inherit name age; }'
{ age = 36; name = "Ada"; }
```

It can copy from an expression:

```console
# nix eval --expr 'let p = { x = 1; y = 2; }; in { inherit (p) x y; }'
{ x = 1; y = 2; }
```

Ordinary attribute values cannot see siblings. `rec` makes attributes recursively visible:

```console
# nix eval --expr 'rec { radius = 3; diameter = radius * 2; }'
{ diameter = 6; radius = 3; }
```

Use `rec` narrowly: hidden sibling dependencies make overrides surprising.

`with set; body` adds set attributes as low-priority names in `body`:

```console
# nix eval --expr 'with { x = 20; y = 22; }; x + y'
42
```

`with` is concise but obscures where names originate. Prefer explicit selection or `inherit` in maintainable code.

## Common Misconceptions

- **“Lists use commas.”** They use whitespace.
- **“Every interpolated value becomes a string.”** Only values coercible to strings can be interpolated.
- **“A URL string downloads data.”** It is only a value.
- **“`//` deeply merges sets.”** It replaces colliding top-level attributes.
- **“`rec` is required in every set.”** Use it only when attributes must refer to one another.
- **“Paths are ordinary strings.”** They are distinct values with copying and resolution semantics.

## Recap

Nix programs combine atomic values, strings, paths, lists, and attribute sets. `let` and lexical scope organize bindings; `inherit` removes repetition; `rec` permits sibling references; and `with` introduces an implicit scope best used sparingly.

## Exercises

1. Create an attribute set with a dynamically named attribute and select it.
2. Demonstrate, with evaluation output, that `//` is shallow.
3. Build a list of squared integers using `map`.
4. Rewrite a `with` expression using explicit attribute selection.
5. Create an indented string containing a literal `${HOME}`.

## Official Sources

- [Nix language values](https://nix.dev/manual/nix/latest/language/values)
- [String interpolation](https://nix.dev/manual/nix/latest/language/string-interpolation)
- [Operators](https://nix.dev/manual/nix/latest/language/operators)
- [Constructs: `let`, `with`, and `inherit`](https://nix.dev/manual/nix/latest/language/constructs)
- [Nix language tutorial](https://nix.dev/tutorials/nix-language)
