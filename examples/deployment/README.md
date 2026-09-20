# Deployment examples

All destinations use `.invalid`, a reserved top-level domain. The checked
examples therefore cannot accidentally address a production host. No file in
this directory performs an action when imported, and the validation commands
below do no network writes.

## Structure

- `topology.nix` is pure data for one canary and two rollout waves.
- `host-module.nix` is an evaluation-only NixOS module: no SSH, key, disk, or
  secret provisioning.
- `nixos-configurations.nix` constructs matching NixOS configurations using
  only Nixpkgs.
- `deploy-rs.nix` is the primary deployment adapter with automatic and magic
  rollback enabled.
- `colmena-hive.nix` expresses the equivalent hosts and cohort tags as a
  Colmena hive.

## Local evaluation

From the repository root:

```console
nix-instantiate --parse examples/deployment/deploy-rs.nix
nix-instantiate --parse examples/deployment/colmena-hive.nix

nix eval --json --file examples/deployment/topology.nix

nix eval --impure --expr '
  let
    root = builtins.getFlake (toString ./.);
    configs = import ./examples/deployment/nixos-configurations.nix {
      nixpkgs = root.inputs.nixpkgs;
    };
  in builtins.mapAttrs (_: value: value.config.system.build.toplevel.drvPath) configs
'

nix eval --impure --expr '
  let
    root = builtins.getFlake (toString ./.);
    configs = import ./examples/deployment/nixos-configurations.nix {
      nixpkgs = root.inputs.nixpkgs;
    };
    deployment = import ./examples/deployment/deploy-rs.nix {
      nixosConfigurations = configs;
      activateNixos = config: config.config.system.build.toplevel;
    };
  in builtins.attrNames deployment.nodes
'
```

The last command uses an evaluation-only activation stub. A real flake should
pass `deploy-rs.lib.x86_64-linux.activate.nixos` and expose the result as
`outputs.deploy`. It should also expose upstream `deployChecks` under
`outputs.checks`.

For Colmena, pass the pinned Nixpkgs input to `colmena-hive.nix`, then wrap the
result with the current upstream `colmena.lib.makeHive` and expose it as
`outputs.colmenaHive`.

## Primary staged deploy-rs runbook

The following commands are documentation, not scripts. They perform remote
writes after real hostnames and credentials are deliberately configured:

```console
# 1. Evaluate and build everything locally; no target activation.
nix flake check
nix build .#nixosConfigurations.canary.config.system.build.toplevel

# 2. Deploy only the canary group.
deploy --groups canary .

# 3. Run organization-specific external health checks, inspect service state,
#    and record the deployed store path. Stop here on any anomaly.

# 4. Expand one bounded cohort at a time.
deploy --groups wave-1 .
deploy --groups wave-2 .
```

Keep `autoRollback` and `magicRollback` enabled. Magic rollback confirms that
the host remains reachable after activation; it is not an application health
check. Use explicit service, traffic, and data-integrity gates between waves.
Changing SSH addressing may require a separately reviewed maintenance
procedure because connectivity confirmation depends on reconnecting.

Equivalent Colmena selectors are:

```console
colmena build
colmena apply --on @canary
colmena apply --on @wave-1
colmena apply --on @wave-2
```

`colmena build` is local evaluation/building; each `apply` performs remote
writes. Colmena's topology here is equivalent, but its activation and rollback
semantics are not identical to deploy-rs magic rollback.

Before adapting either example, provision narrowly scoped SSH access, verify
host keys out of band, pin tool inputs, remove the `.invalid` safety addresses,
and define a tested health and rollback policy.
