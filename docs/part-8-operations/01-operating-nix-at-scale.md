# Part 8 — Operating Nix at Scale

## Chapter 1: Continuous Integration

**Platforms:** `[Linux]` `[macOS]` `[NixOS]` `[CI]`

### Objectives

- Design CI around evaluation, checks, builds, and platform matrices.
- Reuse artifacts without weakening trust.
- Keep CI credentials and permissions narrow.

### A layered pipeline

A useful Nix pipeline separates fast structural feedback from expensive realization:

1. parse/evaluate and run `nix flake check`;
2. verify formatting and repository policy;
3. build package and check outputs for each supported system;
4. build NixOS/nix-darwin/Home Manager activation artifacts;
5. run NixOS VM or application integration tests;
6. upload successful store paths to an authorized binary cache;
7. deploy from a reviewed revision or immutable artifact.

```console
nix flake check --show-trace
nix build --print-build-logs .#packages.x86_64-linux.default
nix build .#nixosConfigurations.atlas.config.system.build.toplevel
```

Evaluation on x86_64 does not build aarch64 artifacts. Use native runners, trusted remote builders, or carefully evaluated emulation. Matrix only the systems the project claims to support; broad default matrices waste resources and may imply false support.

CI should pin Nix installation method and project inputs, expose build logs, and preserve enough metadata to connect artifacts to commits and lock files. Cache the Nix store through a real binary cache, not by treating `/nix/store` as an opaque CI directory cache. Directory caches can break ownership, database, and trust assumptions.

For pull requests from forks, do not expose cache signing keys, deployment credentials, or trusted-builder privileges to unreviewed code. A Nix build expression is code: it can consume accessible environment, exploit overly broad CI permissions, or produce malicious artifacts. Separate untrusted validation from privileged publication.

### Common misconceptions

- **“`nix flake check` builds every output.”** It checks schema and designated checks, normally for the current system.
- **“One Linux runner validates Darwin.”** It can evaluate some expressions but cannot establish native macOS behavior.
- **“Store caching is just archiving `/nix`.”** Correct binary caches include NAR metadata, hashes, signatures, and substituter protocol.
- **“Sandboxing makes secret-bearing CI safe.”** Runner configuration and trusted settings determine actual boundaries.

### Recap

CI should evaluate broadly, build on matching platforms, run semantic tests, and publish only from trusted contexts. Preserve provenance from source revision and lock graph to cache artifact.

### Exercises

1. Define a CI matrix from a flake’s explicit supported systems.
2. Separate fork-safe checks from credentialed cache publication.
3. Add a build of one NixOS toplevel and one VM test.
4. Record lock-file and output-path provenance for a release.

### Official links

- [`nix flake check`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake-check)
- [`nix build`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-build)
- [Nix continuous integration](https://nix.dev/guides/continuous-integration)
- [Nix sandboxing](https://nix.dev/manual/nix/latest/store/types/local-store)

## Chapter 2: Binary Caches, Cachix, Signing, and Trust

**Platforms:** `[Linux]` `[macOS]` `[NixOS]` `[CI]`

### Objectives

- Understand the substituter protocol and NAR metadata.
- Configure caches and public keys without conflating transport and artifact trust.
- Publish through Cachix or another cache with safe key handling.

### Substitution

When realizing a store path, Nix can query substituters before building locally. A binary cache serves compressed NAR archives and `.narinfo` metadata containing the store path, NAR hash and size, references, deriver information, and signatures.

Client configuration typically includes:

```nix
nix.settings = {
  substituters = [
    "https://cache.nixos.org/"
    "https://example.cachix.org"
  ];
  trusted-public-keys = [
    "cache.nixos.org-1:..."
    "example.cachix.org-1:..."
  ];
};
```

Use the exact official key published by the cache operator; placeholders above are not usable values. TLS protects transport to the endpoint. A valid Nix signature authorizes store metadata under a configured public key. Content hashes protect NAR integrity. These mechanisms complement rather than replace one another.

`trusted-users` is a powerful daemon setting: trusted users can influence substituters and other settings in ways that may import privileged artifacts. Do not grant it merely to fix a developer’s cache warning. Prefer centrally configured substituters and keys. `allowed-users` controls daemon access and is not equivalent.

### Cachix workflow

Cachix provides hosted binary caches and a CLI:

```console
cachix use my-cache
nix build .#checks.x86_64-linux.package
cachix push my-cache ./result
```

CI integrations can watch a build and upload newly produced paths. Read-only public caches need no signing secret on clients. Push authentication tokens or signing keys belong only in protected CI contexts, scoped to the required cache and unavailable to forked pull requests. Cachix deployment features are separate from binary-cache substitution; evaluate their trust and rollback model independently.

Private caches additionally require authentication. Avoid embedding tokens in world-readable Nix configuration, derivations, command histories, or logs. Configure credentials through the platform’s protected runtime mechanisms.

### Cache operation

For self-hosted caches, define:

- signing-key custody and rotation;
- immutable object retention and garbage collection;
- availability and regional replication;
- authorization for upload and download;
- provenance tying store paths to CI;
- disaster recovery;
- key revocation and client rollout.

`nix copy --to` and `--from` move store paths between supported stores. Verify paths and signatures with the relevant `nix store verify` workflow for your Nix version. Do not sign artifacts produced by untrusted builders merely because their hashes are internally consistent.

### Common misconceptions

- **“HTTPS makes a binary cache trusted.”** It authenticates transport; Nix keys authorize cache signatures.
- **“Anyone with a public key can upload.”** Public keys verify; upload uses separate credentials/private authority.
- **“`trusted-users` means users whose code is trusted.”** It grants significant daemon configuration power.
- **“A cache hit proves the source was reviewed.”** Provenance and publication policy must establish that relationship.

### Recap

Binary caches substitute verified store objects. Configure exact endpoints and public keys, protect publication credentials, minimize trusted-daemon authority, and preserve artifact provenance.

### Exercises

1. Trace fields from a `.narinfo` response to a local store path.
2. Design cache credentials for fork, branch, and release workflows.
3. Compare transport authentication, content hashes, and Nix signatures.
4. Write a cache key-rotation runbook.

### Official links

- [Nix binary cache files](https://nix.dev/manual/nix/latest/store/types/http-binary-cache-store)
- [Nix store signatures](https://nix.dev/manual/nix/latest/package-management/binary-cache-substituter)
- [`nix copy`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-copy)
- [`nix store verify`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-store-verify)
- [Cachix documentation](https://docs.cachix.org/)

## Chapter 3: Distributed Builds

**Platforms:** `[Linux]` `[macOS]` `[NixOS]` `[Build farm]`

### Objectives

- Route derivations to remote builders by platform and capability.
- Secure builder access and outputs.
- Diagnose scheduling and feature mismatches.

### Builder model

A Nix client can send derivations and inputs to remote Nix stores, let them build, and copy results back. Builders are declared with URI, supported systems, SSH key, concurrency, speed factor, and supported or mandatory features. A representative SSH builder specification conceptually contains:

```text
ssh-ng://builder.example.org x86_64-linux /path/to/key 8 2 kvm,big-parallel
```

Use the exact `builders` syntax from the Nix manual for the installed version; escaping and fields matter. `max-jobs` controls local scheduling, while per-builder job counts constrain remote concurrency. `system-features` such as `kvm`, `big-parallel`, or organization-specific labels let derivations request capabilities.

The scheduler chooses a builder whose system and mandatory features match. It does not make an x86_64 builder capable of native aarch64 output unless the derivation is genuinely cross compiled. macOS license and hardware constraints require real Darwin builders for native Darwin builds.

### Security and reliability

Builder SSH identities should be dedicated, non-interactive, and constrained. The remote daemon and store are a trust boundary. Options such as `builders-use-substitutes` can let builders fetch inputs directly from configured caches, reducing network transfer, but the remote cache policy must be correct.

Decide whether remote outputs are accepted as trusted, signed by a trusted authority after verification, or independently rebuilt for high-assurance workloads. Nix content addressing and input-addressed derivations detect corruption according to their model, but a malicious builder can still produce a malicious output for a derivation whose output is not independently predetermined.

Monitor queue latency, failure rates, disk pressure, cache hit rate, architecture saturation, and builder health. Drain builders before maintenance; retain alternate capacity for critical systems. Avoid one shared mutable SSH key across the fleet.

### Common misconceptions

- **“Remote builders are substituters.”** Builders execute derivations; substituters serve existing artifacts. One host may provide both, but roles differ.
- **“Nix automatically emulates missing architectures.”** Scheduling requires declared platform support or explicit emulation setup.
- **“A successful hash check proves a builder followed the source.”** For ordinary derivations, the output path is input-addressed, not a predeclared content hash.
- **“More remote jobs always improve throughput.”** Network, memory, disk, and dependency serialization can dominate.

### Recap

Distributed builds schedule by platform and features across remote stores. Treat builders as security principals, configure cache access and concurrency deliberately, and measure the farm.

### Exercises

1. Design builders for x86_64 Linux, aarch64 Linux, and Apple Silicon.
2. Label one builder for KVM-required NixOS tests.
3. Threat-model a compromised remote builder.
4. Diagnose a derivation stuck because of a mandatory system feature.

### Official links

- [Distributed builds](https://nix.dev/manual/nix/latest/advanced-topics/distributed-builds)
- [Nix configuration reference](https://nix.dev/manual/nix/latest/command-ref/conf-file)
- [Remote store](https://nix.dev/manual/nix/latest/store/types/ssh-store)
- [SSH-ng store](https://nix.dev/manual/nix/latest/store/types/ssh-ng-store)

## Chapter 4: Hydra

**Platforms:** `[Linux]` `[NixOS]` `[Build farm]`

### Objectives

- Understand Hydra projects, jobsets, evaluations, builds, and channels.
- Expose evaluable jobs without coupling project structure to Hydra internals.
- Operate Hydra as a stateful, privileged service.

### Hydra’s model

Hydra continuously evaluates declared inputs and schedules derivations:

- a **project** groups related automation;
- a **jobset** identifies inputs and an evaluation expression or flake;
- an **evaluation** computes jobs for particular input revisions;
- a **build** realizes one derivation;
- build products and aggregate status support release workflows;
- channels can expose successful package sets.

Flakes may export `hydraJobs`:

```nix
hydraJobs = {
  inherit (self.packages.x86_64-linux) server cli;
  tests = self.checks.x86_64-linux;
};
```

Hydra traverses supported job structures and expects derivations at build leaves. Keep arbitrary functions and huge unevaluated package universes out of job outputs. Jobsets should pin source inputs and make evaluation failures visible.

Hydra is more than a stateless CI runner. It uses a database, maintains evaluation/build history, coordinates build machines, serves logs and artifacts, and often signs or publishes cache results. Back up the database and signing material separately, control evaluator and web permissions, monitor queue and evaluator health, and plan garbage collection around roots Hydra must retain.

Do not expose secrets as jobset string inputs when they can reach expressions or logs. Keep privileged publication stages separate from untrusted pull-request evaluation. Hydra plugins and evaluator code expand the attack surface and need patching.

### When to use Hydra

Hydra fits continuous evaluation of many Nix jobs, channels, and build farms. A general CI service plus a Nix binary cache may be simpler for small repositories or workflows dominated by non-Nix orchestration. Choose based on job volume, Nix-native scheduling needs, operational capacity, and access-control requirements.

### Common misconceptions

- **“Hydra is only a web UI for `nix build`.”** It manages evaluations, scheduling, history, products, and release/cache workflows.
- **“`hydraJobs` can contain any flake value.”** Job traversal needs supported derivation-shaped leaves.
- **“Hydra removes the need for a binary cache.”** It commonly publishes build products through cache infrastructure.
- **“Running Hydra is maintenance-free because configuration is declarative.”** Database, keys, workers, storage, and upgrades remain operational responsibilities.

### Recap

Hydra is a Nix-native continuous build service with state and privileged publication responsibilities. Keep job outputs focused, secure evaluation boundaries, and operate its database, workers, cache, and keys as production infrastructure.

### Exercises

1. Export packages and checks through `hydraJobs`.
2. Design separate untrusted evaluation and trusted publication jobsets.
3. Write backup and restore objectives for Hydra state.
4. Decide whether a small project benefits from Hydra or ordinary CI plus Cachix.

### Official links

- [Hydra manual](https://nixos.org/hydra/manual/)
- [Hydra repository](https://github.com/NixOS/hydra)
- [Hydra NixOS options](https://search.nixos.org/options?query=services.hydra)
- [Flake `hydraJobs`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake#flake-format)

## Chapter 5: Deployment Patterns and Safe Rollouts

**Platforms:** `[NixOS]` `[macOS]` `[Linux]` `[Fleet]`

### Objectives

- Choose push, pull, image, or orchestrated deployment.
- Separate build, copy, activation, health validation, and rollback.
- Handle mutable application state safely.

### Patterns

**Push deployment:** CI or an operator builds a system, copies closures to a host, and activates remotely. This gives centralized control and clear artifact selection but requires privileged remote access.

**Pull deployment:** each host polls a signed, approved revision or artifact and activates it. This reduces inbound control paths but requires robust host-side authentication, convergence, reporting, and protection against replay or bad desired state.

**Image deployment:** build VM, cloud, installer, or OCI images and replace instances. This is strong for immutable infrastructure but persistent state and image boot validation remain separate.

**Deployment orchestrators:** tools such as Colmena, deploy-rs, morph, and Cachix Deploy coordinate evaluation, copying, activation, and rollback. They are external projects with distinct security and health-check semantics. Pin the tool, read its current documentation, and understand what “rollback” covers.

### A safe release sequence

1. merge a reviewed source revision and lock graph;
2. evaluate every intended host;
3. build system closures on trusted builders;
4. sign/publish immutable store paths;
5. deploy to a canary;
6. activate with a bounded timeout;
7. check service, network, and application health;
8. pause or roll back on failure;
9. expand through cohorts;
10. retain previous generations and record results.

`nix copy --to ssh-ng://host ...` can transfer closures, while `nixos-rebuild --target-host` supports direct workflows. Avoid building production policy from an uncommitted operator tree unless that is an explicitly recorded emergency procedure.

### State, rollback, and secrets

A system profile rollback does not reverse database schema changes, object-store writes, secret rotation, or external API actions. Use backward-compatible migrations: expand schema, deploy compatible code, migrate data, then contract in a later release. Back up and test restore before destructive migrations.

Secrets should be delivered to the target at runtime or activation with auditable authorization. If a deployment tool holds fleet-wide credentials, isolate it, require review for policy changes, and scope host access. Record artifact path, source revision, actor, target, health result, and rollback.

macOS activation through nix-darwin may require interactive or platform-specific privileges and cannot provide NixOS boot-generation semantics. Mixed fleets need platform-specific health and recovery plans.

### Common misconceptions

- **“Declarative means deployment is automatically atomic.”** Store/profile changes are atomic; distributed services and mutable state are not.
- **“Rollback always restores the previous application.”** Data migrations and external side effects may prevent it.
- **“Building on the target is more reproducible.”** Reproducibility depends on declared inputs; centralized trusted builds often improve provenance.
- **“One successful canary proves the fleet is safe.”** Hardware, architecture, region, data, and traffic differences require representative cohorts.

### Recap

Deployment turns immutable build outputs into mutable operational change. Separate stages, publish trusted artifacts, canary representative hosts, validate health, and design data migration and recovery beyond Nix generations.

### Exercises

1. Compare push and pull deployment for an intermittently connected fleet.
2. Design a canary and cohort strategy across two architectures and regions.
3. Write a rollback plan for a release containing a database migration.
4. Define an audit record connecting source, store path, host, and outcome.

### Official links

- [`nixos-rebuild`](https://nixos.org/manual/nixos/stable/#sec-changing-config)
- [`nix copy`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-copy)
- [NixOS rollback](https://nixos.org/manual/nixos/stable/#sec-rollback)
- [NixOS image building](https://nixos.org/manual/nixos/stable/#sec-building-image)
- [Nix store concepts](https://nix.dev/manual/nix/latest/store/)
