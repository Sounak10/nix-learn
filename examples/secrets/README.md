# Secrets examples

These examples are deliberately inert. They contain no private key, usable
credential, or decryptable production secret, and no command runs merely by
evaluating a Nix file.

## Files

- `runtime-secret-contract.nix` is a dependency-free module showing the
  runtime-file contract a service should consume.
- `sops-nix.nix` is the primary NixOS module fragment. It expects the
  `sops-nix` module and a real encrypted `secrets.yaml` supplied by the
  operator; that file is intentionally absent.
- `agenix.nix` is the equivalent `agenix` module fragment. It expects an
  encrypted `service-token.age`, also intentionally absent.
- `.sops.yaml.example` is policy scaffolding with unmistakable recipient
  placeholders. Copy it to `.sops.yaml`, replace every placeholder with real
  **public** recipients, and review the diff before encrypting anything.
- `secrets.example.yaml` is a schema-only plaintext template. Never put a real
  value in this tracked file.

The third-party fragments are syntax-checkable without fetching their tools:

```console
nix-instantiate --parse examples/secrets/sops-nix.nix
nix-instantiate --parse examples/secrets/agenix.nix
```

The runtime contract can also be evaluated with only this repository's pinned
Nixpkgs:

```console
nix eval --impure --expr '
  let
    root = builtins.getFlake (toString ./.);
    result = root.inputs.nixpkgs.lib.evalModules {
      modules = [
        ./examples/secrets/runtime-secret-contract.nix
        { lab.runtimeSecretFile = "/run/secrets/example-service-token"; }
      ];
    };
  in result.config.lab.serviceEnvironment
'
```

## Safe local workflow

1. Generate an age identity on an encrypted operator device:
   `age-keygen -o ~/.config/sops/age/keys.txt`.
2. Back up the identity through the approved recovery channel; never commit it.
3. Put only its `age1...` public recipient in the copied `.sops.yaml`.
4. Create an untracked `secrets.yaml` with `sops secrets.yaml`.
5. Add host and recovery public recipients before removing an old recipient:
   `sops updatekeys secrets.yaml`.
6. Deploy the encrypted file and let the target materialize plaintext under
   `/run`; applications receive only the runtime pathname.

Commands above mutate only explicitly named local files. None is run
automatically.

See the cookbook chapter for custody, CI, rotation, recovery, and failure-mode
guidance.
