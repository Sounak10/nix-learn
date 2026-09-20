# Part 8 — Secrets and Deployment Cookbook

**Platforms:** `[NixOS]` `[Linux]` `[CI]` `[Fleet]`

This chapter separates two concerns that are often accidentally coupled:

- a secret manager commits ciphertext and materializes plaintext at runtime;
- a deployment tool builds, copies, activates, checks, and possibly rolls back
  NixOS closures.

Nix makes configuration reproducible; it does not make plaintext safe in the
Nix store or make a distributed rollout transactional.

## 1. Choosing sops-nix or agenix

Both projects keep encrypted files in source control and decrypt them during
activation. Both can use age recipients, expose runtime paths to NixOS modules,
set file ownership and modes, and avoid putting decrypted values in the Nix
store when used correctly.

### sops-nix

Choose `sops-nix` when structured files and broader SOPS interoperability are
valuable:

- YAML, JSON, dotenv, INI, and binary inputs;
- age, PGP, and cloud KMS recipients supported by SOPS;
- one encrypted document can contain several named values;
- templates can construct a runtime configuration from multiple secrets;
- SOPS creation rules and key groups express recipient policy.

The larger format and recipient surface is useful but creates more policy to
audit. Field names and unencrypted metadata may still reveal structure. A
whole-file recipient change normally uses `sops updatekeys`.

### agenix

Choose `agenix` when one age-encrypted file per secret and Nix-defined recipient
rules are preferable:

- a small age-focused model;
- recipient policy in `secrets.nix`;
- straightforward `/run/agenix/<name>` runtime paths;
- `agenix --rekey` updates files after recipient rules change.

It does not provide SOPS structured-document/KMS features. One-file-per-secret
can make ownership and review obvious, but can create many files and repeated
rekey work. Password-protected SSH identities are awkward for bulk operations
because age does not use `ssh-agent` for them.

### Decision

The security result depends more on recipient policy, private-key custody,
runtime permissions, logging, recovery, and rotation than on this choice. Do
not decrypt during a Nix build with either tool. This cookbook uses
**sops-nix + age** as the primary workflow and includes an agenix counterpart
under `examples/secrets/`.

## 2. Primary workflow: sops-nix with age

The tracked repository contains:

1. `.sops.yaml`, with public recipient policy only;
2. `secrets.yaml`, containing SOPS ciphertext and metadata;
3. a NixOS module declaring which key to materialize and who may read it.

It must not contain an age identity, plaintext secret, unredacted recovery
export, CI credential, or decrypted generated configuration.

### Create and custody identities

Generate a dedicated operator identity on an encrypted administrative device:

```console
umask 077
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
age-keygen -y ~/.config/sops/age/keys.txt
```

The second command prints the public `age1...` recipient. It is safe to commit
the public recipient, though it can identify infrastructure. The
`AGE-SECRET-KEY-...` identity is sensitive.

Prefer a dedicated, persistent host identity provisioned outside the Nix store.
Using an SSH host key as an age identity reduces provisioning work but couples
secret access to SSH host-key custody and rotation. If that trade-off is
accepted, derive only a public age recipient for policy:

```console
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
```

Never copy `/etc/ssh/ssh_host_ed25519_key` into the repository or pass it as a
Nix path. On impermanent systems, persist the dedicated age identity before
activation. A generated-on-first-boot identity needs a secure process to return
its public recipient and re-encrypt secrets before the host can decrypt them.

Maintain at least:

- one recipient per authorized target or role;
- narrowly scoped operator access for editing;
- an offline recovery recipient held separately;
- an inventory mapping recipients to owners, hosts, expiry, and revocation.

Back up identities encrypted under an independently controlled recovery
mechanism. Test recovery on a disposable system. A backup that has never been
restored is only an assumption.

### Define recipient policy and encrypt

Start from `examples/secrets/.sops.yaml.example`. Replace every marked value
with a real **public** recipient. Then create the real encrypted document:

```console
cp examples/secrets/.sops.yaml.example .sops.yaml
$EDITOR .sops.yaml
sops secrets.yaml
```

These commands modify local files; inspect `git diff` before committing. Start
from the schema in `examples/secrets/secrets.example.yaml`, but never put a real
value into that tracked plaintext example.

Verify that the committed file contains `ENC[...]` values and a `sops` metadata
section:

```console
sops --decrypt secrets.yaml >/dev/null
git diff --check
```

The first command tests local decryptability but directs plaintext to
`/dev/null`. Avoid `sops -d` to a terminal in shared sessions: terminals,
scrollback, screen recordings, and logs are disclosure channels.

### Materialize at activation, outside the store

Import the upstream `sops-nix.nixosModules.sops` module in the real system and
adapt `examples/secrets/sops-nix.nix`. The important contract is:

```nix
sops.defaultSopsFile = ./secrets.yaml; # ciphertext may enter the store
sops.age.keyFile = "/var/lib/sops-nix/key.txt"; # string runtime path
sops.secrets."example-service/token" = {
  owner = "example-service";
  mode = "0400";
};
```

The encrypted source may be copied to `/nix/store`; that is expected. The
private identity and decrypted value must not be. `sops-nix` materializes
secrets below `/run/secrets.d` and exposes stable symlinks below
`/run/secrets`. Pass `config.sops.secrets.<name>.path` to the service.

Use a file-path interface such as `SERVICE_TOKEN_FILE`, systemd credentials, or
an application's `--token-file` option. Do not do this:

```nix
# UNSAFE: evaluation reads plaintext and interpolation copies it into the store.
environment.etc."app.conf".text =
  "token=${builtins.readFile /run/secrets/example-service-token}";
```

Do not put plaintext in `environment.variables`, derivation arguments,
`writeText`, generated packages, assertions, traces, command lines, or logs.
For a configuration format that cannot include files, use a sops-nix runtime
template, restrict its owner/mode, and pass the template's `.path`.

Secrets needed before normal users exist require special early-activation
handling such as `neededForUsers`; use it only for the documented case, because
it changes timing and available ownership. Prefer `hashedPasswordFile` over a
plaintext password. Configure `restartUnits` or `reloadUnits` deliberately:
rewriting a file does not guarantee the application rereads it.

### Rotation without an outage

Recipient rotation and credential rotation are different operations.

To rotate an age recipient:

1. create and securely deliver the new private identity;
2. add its public recipient while retaining the old and recovery recipients;
3. run `sops updatekeys secrets.yaml`;
4. review and commit the ciphertext-only change;
5. deploy to a canary and prove it decrypts;
6. deploy remaining hosts;
7. remove the old public recipient and run `sops updatekeys` again;
8. revoke/destroy the old private identity according to policy.

To rotate an application credential:

1. issue a new credential with overlap where the provider supports it;
2. edit the SOPS value;
3. deploy and verify every consumer;
4. revoke the old credential at the provider;
5. record the result without recording the value.

Re-encryption does not revoke a leaked plaintext credential, and deleting a
recipient from policy does not erase old ciphertext from Git history. Assume
any former recipient could retain any version it could decrypt.

## 3. CI and failure modes

Untrusted pull requests should parse and evaluate declarations without any
decryption identity. CI can validate that encrypted files exist and are
well-formed, evaluate NixOS systems, build closures, and reject likely
plaintext patterns. Use fake service fixtures for integration tests.

If a protected deployment job must decrypt, use an ephemeral runner or
short-lived identity, restrict it to reviewed branches/environments, mask
output, disable shell tracing, and delete workspace and process state
afterward. Better still, let each target decrypt its own secret so CI never
holds fleet plaintext. Never expose identities to forked pull requests.

Diagnose failures by layer:

- **No matching identity:** wrong recipient, wrong host identity, missing
  persisted key, or stale ciphertext. Compare public recipients; do not print
  private keys.
- **Works until reboot:** the identity was placed on ephemeral storage, or
  ordering is wrong. Persist it and declare dependencies.
- **Permission denied:** owner/group/mode or service sandbox is wrong. Inspect
  metadata, not file contents.
- **Service still uses old value:** reload/restart policy is absent or the
  application cached the credential.
- **Secret appears in the store:** plaintext was read during evaluation/build
  or interpolated into generated output. Treat it as disclosed, rotate it, and
  fix the interface; deleting one store path is insufficient.
- **New host cannot decrypt:** its public recipient was not present when the
  file was encrypted. Add it and update keys before rollout.
- **Lost sole identity:** ciphertext is unrecoverable. Restore the tested
  recovery identity or issue replacement application credentials.
- **SOPS merge conflicts:** decrypt/edit through SOPS and re-encrypt from a
  reviewed base; do not hand-edit `ENC[...]` payloads.

## 4. Direct deployment and installation

### `nixos-rebuild --target-host`

For a small fleet or break-glass procedure:

```console
# Local evaluation/build only.
nixos-rebuild build --flake .#canary

# REMOTE WRITE: copy and activate on the target.
nixos-rebuild switch \
  --flake .#canary \
  --target-host deploy@canary.ops.example.invalid \
  --use-remote-sudo
```

The target must already be reachable and authorized. `--build-host` selects
where realization happens; `--target-host` selects where activation happens.
Do not confuse either with an application health check. Prefer a reviewed,
locked revision; verify SSH host keys; retain a working generation; and use
`boot` instead of `switch` when the policy requires activation only after a
reboot.

### `nixos-anywhere`

`nixos-anywhere` installs NixOS over SSH and commonly uses Disko. It is for
provisioning/reinstallation, not routine rollout. Disk selection mistakes are
destructive.

```console
# Non-destructive local VM exercise when the configuration supports it.
nix run github:nix-community/nixos-anywhere -- \
  --flake .#canary --vm-test

# DESTRUCTIVE REMOTE WRITE — documentation only; review disks and backups.
nix run github:nix-community/nixos-anywhere -- \
  --flake .#canary \
  --target-host root@INSTALLER_ADDRESS_REPLACE_ME
```

Pin the tool in production instead of deploying an unreviewed moving branch.
Inventory disks from an independent source, test Disko in a VM, back up data,
verify installer host keys, ensure post-install SSH access is declared, and
expect the installed host key to differ. Provision the age identity through a
secure extra-files/secret mechanism or after install; never embed it in the
flake or disk image.

## 5. Primary fleet workflow: deploy-rs

`deploy-rs` consumes flake `deploy.nodes` profiles. A system profile uses
`deploy-rs.lib.<system>.activate.nixos`, and upstream `deployChecks` can validate
the deployment schema during `nix flake check`.

`examples/deployment/` defines three non-routable hosts:

- `canary`, tagged `canary`;
- `web-a`, tagged `wave-1`;
- `web-b`, tagged `wave-2`.

Its deploy-rs adapter enables:

- `autoRollback`, to roll back after activation failure;
- `magicRollback`, to roll back unless the client reconnects and confirms;
- a bounded confirmation timeout;
- one root system profile reached through a dedicated SSH user.

Magic rollback protects connectivity, not application correctness, schema
compatibility, latency, or external side effects. Keep an independent health
gate between cohorts.

### Staged runbook

1. pin inputs and select a reviewed revision;
2. evaluate deployment checks and all NixOS configurations;
3. build closures on trusted builders;
4. deploy only the canary group;
5. verify SSH reconnection, systemd state, application probes, metrics, logs,
   and data compatibility;
6. pause for an observation window;
7. deploy `wave-1`, repeat the gate, then deploy `wave-2`;
8. record revision, lock hash, store path, actor, host, health result, and
   rollback outcome.

The exact inert commands are documented in
`examples/deployment/README.md`. Replace `.invalid` addresses only in an
operational repository with reviewed access policy. A rollback changes the
profile generation; it does not reverse database migrations, remote API calls,
queued work, or credential revocation. Use expand/migrate/contract database
changes and test restore separately.

## 6. Equivalent Colmena topology

Colmena represents a fleet as a hive. Per-node `deployment.targetHost`,
`deployment.targetUser`, and `deployment.tags` describe the same three hosts
and rollout cohorts in `examples/deployment/colmena-hive.nix`.

```console
# Local build; no activation.
colmena build

# REMOTE WRITES, one reviewed cohort at a time.
colmena apply --on @canary
colmena apply --on @wave-1
colmena apply --on @wave-2
```

Equivalent topology does not mean equivalent failure semantics. Do not assume
Colmena supplies deploy-rs magic rollback. Read the pinned Colmena version's
activation, parallelism, replacement, and rollback behavior; set conservative
limits; and use the same external gates. Interactive SSH authentication is not
a suitable fleet mechanism—use dedicated, scoped keys and a reviewed sudo
policy.

## 7. Production checklist

- Ciphertext only in Git and the Nix store; plaintext only in restricted
  runtime files.
- Dedicated host/operator/recovery recipients with inventory and tested restore.
- No private identity represented as a Nix path.
- Secrets absent from derivations, environment dumps, process arguments, logs,
  traces, test snapshots, and cache artifacts.
- Protected CI has least privilege; untrusted CI has no decryption or deploy
  credential.
- Tool inputs and lock graph are reviewed and pinned.
- SSH host verification and narrowly scoped sudo are enforced.
- All closures build before activation; canary and cohorts have explicit gates.
- Previous generations remain bootable, with out-of-band access tested.
- Stateful migrations and external side effects have their own rollback plan.
- Audit records identify source revision and store path, never secret values.

## Official sources

- [sops-nix README and module usage](https://github.com/Mic92/sops-nix)
- [SOPS documentation](https://getsops.io/docs/)
- [age documentation](https://age-encryption.org/)
- [agenix README and reference](https://github.com/ryantm/agenix)
- [NixOS manual: changing configuration and rollback](https://nixos.org/manual/nixos/stable/#sec-changing-config)
- [`nixos-rebuild` reference](https://nixos.org/manual/nixos/stable/#sec-nixos-rebuild)
- [nixos-anywhere documentation](https://nix-community.github.io/nixos-anywhere/)
- [Disko documentation](https://github.com/nix-community/disko)
- [deploy-rs README and interface](https://github.com/serokell/deploy-rs)
- [Colmena manual](https://colmena.cli.rs/)
