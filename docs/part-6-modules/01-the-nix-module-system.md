# Part 6 — The Nix Module System

## Chapter 1: Evaluation and the Module Fixpoint

**Platforms:** `[NixOS]` `[Home Manager]` `[nix-darwin]` `[Library]`

### Objectives

- Understand modules as declarations merged into a fixed point.
- Separate option declarations from configuration definitions.
- Pass arguments without creating evaluation cycles.

### Module shape

A module is commonly a function returning an attribute set:

```nix
{ config, lib, pkgs, ... }:
{
  imports = [ ./logging.nix ];

  options.services.example.enable =
    lib.mkEnableOption "the example service";

  config = lib.mkIf config.services.example.enable {
    environment.systemPackages = [ pkgs.example ];
  };
}
```

The module system collects `imports`, option declarations, and definitions from all modules, then computes a mutually recursive result. `config` is the merged configuration, `options` describes declared options, `lib` provides module combinators, and additional arguments depend on the caller. This recursion allows one option to influence another, but it also means structural decisions cannot always depend on values that are only known after merging.

`imports` must be determined before the full `config` fixpoint. Therefore this is unsafe:

```nix
imports = lib.optionals config.services.example.enable [ ./example.nix ];
```

Import the module unconditionally and guard its `config` with `mkIf`. `mkIf` pushes a condition down into definitions in a way the module evaluator can handle; ordinary Nix `if` around a recursively dependent configuration can cause infinite recursion.

### Module arguments

NixOS `specialArgs` are available while resolving imports. `_module.args` adds arguments through module configuration, but those arguments cannot safely determine imports because they are computed too late. Home Manager exposes `extraSpecialArgs`; nix-darwin provides corresponding composition hooks.

Pass narrow data:

```nix
nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = {
    site = {
      domain = "example.org";
      region = "eu-west";
    };
  };
  modules = [ ./configuration.nix ];
}
```

Avoid hidden ambient imports such as `<nixpkgs>` inside reusable modules. Use the caller-provided `pkgs`, and export package-set customization separately when needed.

### Free-floating definitions

Definitions carry source locations and priority metadata. `lib.mkDefinition` can construct a free-floating definition while retaining useful error provenance. This is advanced machinery for forwarding definitions; normal modules should use ordinary option assignment.

### Common misconceptions

- **“Modules execute top to bottom.”** They contribute definitions to a merge and fixed-point evaluation.
- **“`config` is whatever this file assigned.”** It is the merged result of all modules.
- **“Conditional imports and conditional config are equivalent.”** Imports establish the module graph before option values are fully available.
- **“`specialArgs` and `_module.args` are identical.”** Their availability during import resolution differs.

### Recap

Modules declare a graph of typed options and conditional definitions. Keep imports structurally decidable, use `mkIf` for value-dependent configuration, and pass only explicit composition data.

### Exercises

1. Convert a recursive conditional import into an unconditional import plus `mkIf`.
2. Pass a site domain through `specialArgs`.
3. Inspect `config`, `options`, and module arguments in a small `lib.evalModules` experiment.
4. Explain why reading `config` while computing `imports` can recurse.

### Official links

- [NixOS module system](https://nixos.org/manual/nixos/stable/#sec-writing-modules)
- [Module system deep dive](https://nix.dev/tutorials/module-system/)
- [`lib.evalModules`](https://nixos.org/manual/nixpkgs/stable/#module-system-lib-evalModules)
- [Module arguments](https://nixos.org/manual/nixpkgs/stable/#module-system-module-arguments)

## Chapter 2: Options, Types, and Assertions

**Platforms:** `[NixOS]` `[Home Manager]` `[nix-darwin]` `[Library]`

### Objectives

- Declare documented options with precise types and defaults.
- Model nested and repeatable configuration with submodules.
- Validate relationships with assertions and warnings.

### Declaring options

```nix
options.services.acme = {
  enable = lib.mkEnableOption "Acme";

  package = lib.mkPackageOption pkgs "acme" { };

  port = lib.mkOption {
    type = lib.types.port;
    default = 8080;
    example = 9090;
    description = "TCP port on which Acme listens.";
  };

  mode = lib.mkOption {
    type = lib.types.enum [ "development" "production" ];
    default = "production";
  };
};
```

`default` is an actual low-priority definition. `example` is documentation only. `description` should explain behavior and security implications rather than repeat the option name. `readOnly` restricts normal redefinition but is not a secret or security boundary. `internal` hides an option from normal generated documentation.

Useful types include:

- `bool`, `int`, `positive`, `port`, `float`, `str`, `nonEmptyStr`;
- `path`, `package`, `anything`;
- `enum`, `oneOf`, `either`, `nullOr`;
- `listOf`, `attrsOf`, `lazyAttrsOf`;
- `submodule`, `submoduleWith`;
- `functionTo`, `coercedTo`;
- `uniq`, `addCheck`.

Choose the narrowest accurate type. Beware that `types.path` copies literal paths into the store when used in derivation-relevant configuration, which can expose readable source contents. `anything` sacrifices useful validation and merging semantics.

### Submodules

Submodules provide repeated structured configuration:

```nix
options.services.acme.instances = lib.mkOption {
  default = {};
  type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
    options = {
      enable = lib.mkEnableOption "instance ${name}";
      port = lib.mkOption {
        type = lib.types.port;
      };
      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/acme-${name}";
      };
    };
  }));
};
```

In an `attrsOf (submodule ...)`, `name` identifies the attribute key. Submodule options merge across definitions. Use `listOf (submodule ...)` when order and duplicates are semantically meaningful, and `attrsOf` when stable names are primary keys.

### Assertions and warnings

Types validate individual values. Integrations such as NixOS declare and
process `assertions` and `warnings`, which validate relationships:

```nix
config = lib.mkIf cfg.enable {
  assertions = [{
    assertion = cfg.port != 22;
    message = "services.acme.port must not collide with SSH.";
  }];

  warnings = lib.optional (cfg.mode == "development")
    "Acme development mode is not suitable for production.";
};
```

Prefer a precise type or conditional configuration when possible. Assertions should fail early with actionable messages; warnings should identify risk without creating permanent noise.
Bare `lib.evalModules` does not provide these options automatically: a
standalone module framework must declare and process them itself.

### Common misconceptions

- **“`example` supplies a fallback.”** Only `default` contributes a definition.
- **“An option type is just documentation.”** Types validate and define merge behavior.
- **“`readOnly` protects secrets.”** It only affects module definitions.
- **“Submodules are separate evaluations with no merge.”** Their options participate in structured module merging.

### Recap

Well-designed options are typed APIs. Use submodules for named or ordered structures and assertions for cross-option invariants.

### Exercises

1. Design options for multiple reverse-proxy virtual hosts.
2. Replace an `anything` option with a useful structured type.
3. Add an assertion requiring TLS when a public-listen option is enabled.
4. Compare `attrsOf` and `lazyAttrsOf` evaluation behavior.

### Official links

- [Option declarations](https://nixos.org/manual/nixos/stable/#sec-option-declarations)
- [Module-system types](https://nixos.org/manual/nixos/stable/#sec-option-types)
- [Submodules](https://nixos.org/manual/nixos/stable/#section-option-types-submodule)
- [Assertions and warnings](https://nixos.org/manual/nixos/stable/#sec-assertions)

## Chapter 3: Merge Priorities and Ordering

**Platforms:** `[NixOS]` `[Home Manager]` `[nix-darwin]` `[Library]`

### Objectives

- Resolve conflicting definitions with explicit priorities.
- Distinguish override priority from list ordering.
- Use merge combinators without erasing user configuration.

### Priority

When definitions conflict, lower numeric priority wins. Ordinary definitions have priority 100. Common combinators:

- `lib.mkDefault value`: priority 1000, easy for users to replace.
- ordinary assignment: priority 100.
- `lib.mkForce value`: priority 50, should be rare.
- `lib.mkOverride n value`: explicit numeric priority.
- option-declaration `default`: priority 1500.

Equal-priority scalar conflicts produce an error rather than silently choosing based on file order. Mergeable types—lists, attribute sets, and submodules—use type-specific merge behavior.

```nix
services.acme.port = lib.mkDefault 8080;
services.acme.enable = lib.mkForce false;
```

Module authors should normally expose defaults in option declarations or use
`mkDefault` for policy profiles. `mkForce` overrides ordinary and default
definitions and therefore severely restricts downstream composition, but it
is not absolutely final: a lower numeric override priority can still win and
equal-priority scalar conflicts can still fail. Use it mainly for deliberate
policy boundaries.

### Order

Order controls merge sequence, not conflict resolution:

```nix
environment.systemPackages =
  lib.mkBefore [ pkgs.diagnostic-tool ];

systemd.services.acme.after =
  lib.mkAfter [ "network-online.target" ];

boot.kernelModules = lib.mkOrder 500 [ "early-module" ];
```

The conventional default order is 1000; `mkBefore` is 500 and `mkAfter` is 1500. Priority answers “which definitions survive?” Order answers “in what sequence are surviving mergeable values combined?”

`lib.mkMerge` combines multiple configuration fragments:

```nix
config = lib.mkMerge [
  (lib.mkIf cfg.enable { environment.systemPackages = [ cfg.package ]; })
  (lib.mkIf cfg.openFirewall { networking.firewall.allowedTCPPorts = [ cfg.port ]; })
];
```

`lib.optionalAttrs` is useful for ordinary attribute construction, but `mkIf` preserves module-level conditional semantics and is generally safer when a condition depends on `config`.

### Renames and removals

Public module APIs evolve. Use the module library’s rename and removal helpers to provide migration errors or aliases where appropriate. An alias can preserve behavior temporarily; a removed-option module should explain the replacement. Do not maintain two independent option definitions that can drift.

### Common misconceptions

- **“Higher number means stronger.”** Lower numeric priority wins.
- **“`mkBefore` overrides another value.”** It changes list ordering only.
- **“Last imported module wins.”** Equal-priority non-mergeable definitions conflict.
- **“`mkForce` is the normal way to set policy.”** It often makes modules hostile to composition.

### Recap

Priority selects definitions; ordering sequences surviving mergeable definitions. Defaults should yield to users, hard forcing should be exceptional, and API migrations should be explicit.

### Exercises

1. Predict the result of option default, `mkDefault`, ordinary, and `mkForce` definitions.
2. Build a list with `mkBefore` and `mkAfter`.
3. Replace a forced setting with a typed option and default.
4. Add an option rename with a useful migration message.

### Official links

- [Setting priorities](https://nixos.org/manual/nixos/stable/#sec-option-definitions-setting-priorities)
- [Ordering definitions](https://nixos.org/manual/nixos/stable/#sec-option-definitions-ordering)
- [Merging configurations](https://nixos.org/manual/nixos/stable/#sec-option-definitions)
- [Module library reference](https://nixos.org/manual/nixpkgs/stable/#module-system)

## Chapter 4: Building Reusable Module Libraries

**Platforms:** `[NixOS]` `[Home Manager]` `[nix-darwin]` `[Library]`

### Objectives

- Separate portable policy from platform-specific implementation.
- Test modules without assembling a full machine.
- Publish modules with stable, discoverable interfaces.

### Layering and portability

A reusable module should:

1. declare options under a specific namespace;
2. bind `cfg = config.<namespace>`;
3. emit configuration under `mkIf cfg.enable`;
4. use caller-provided packages and libraries;
5. avoid host names, usernames, and private paths;
6. document platform assumptions.

NixOS, Home Manager, and nix-darwin all use the Nix module system, but their option trees and argument sets differ. Share plain data functions and narrowly scoped helper modules; do not assume a NixOS module can be imported into Home Manager merely because both are modules.

```nix
let
  evaluated = lib.evalModules {
    modules = [
      ./module.nix
      {
        options.result = lib.mkOption { type = lib.types.str; };
        config.services.acme = {
          enable = true;
          port = 8123;
        };
      }
    ];
    specialArgs = { inherit pkgs; };
  };
in evaluated.config
```

Standalone `evalModules` tests can verify defaults, merges, and type errors.
They can verify assertions only when the standalone framework declares and
processes an assertion option. NixOS modules that depend on NixOS options
should instead be tested with `nixosSystem` or imported alongside the required
option declarations. For runtime behavior, use NixOS VM tests.

Export reusable modules under named flake outputs and include a `default` only when there is a natural primary module:

```nix
nixosModules = {
  acme = import ./modules/nixos/acme.nix;
  default = self.nixosModules.acme;
};
```

### Common misconceptions

- **“All module systems have the same options.”** They share an evaluator pattern, not one global schema.
- **“A successful `evalModules` test proves a service starts.”** It proves evaluation properties only.
- **“Modules should import their own pinned Nixpkgs.”** That fights caller composition.
- **“Exporting only a host configuration is reusable.”** Consumers generally need modules and packages separately.

### Recap

Reusable modules expose typed policy, accept caller context, and separate platform implementations. Test merge behavior at evaluation time and runtime behavior at the system level.

### Exercises

1. Extract host-specific values from a reusable service module.
2. Add an evaluation test for a default and an assertion.
3. Export named NixOS and Home Manager modules separately.
4. Identify which shared logic should be a plain Nix function instead of a module.

### Official links

- [`lib.evalModules`](https://nixos.org/manual/nixpkgs/stable/#module-system-lib-evalModules)
- [NixOS testing](https://nixos.org/manual/nixos/stable/#sec-nixos-tests)
- [Home Manager manual](https://nix-community.github.io/home-manager/)
- [nix-darwin modules](https://daiderd.com/nix-darwin/manual/index.html)
