# CI and Cache Cookbook

**Platforms:** `[GitHub Actions]` `[Linux]` `[macOS]` `[Caches]`

## Objectives

- separate cross-system evaluation from native builds;
- run repository checks with least-privilege GitHub Actions permissions;
- add Cachix or Attic publication without exposing credentials to pull requests; and
- adopt a reviewable lock-update policy.

## Evaluate broadly, build natively

Nix can often evaluate output metadata for another system, but a runner cannot
normally build that system's derivations. Use two layers:

1. a cheap Linux job evaluates the flake and every declared system; and
2. a matrix uses native Linux and macOS runners to run checks and build outputs.

```console
nix flake metadata
nix flake check --no-build --all-systems --show-trace
nix eval --json .#packages.aarch64-darwin --apply builtins.attrNames
nix flake check --show-trace
./scripts/check
```

`--all-systems --no-build` catches output-shape and evaluation failures but is
not proof that foreign packages build or run. GitHub-hosted x86_64 Linux and
arm64 macOS runners cover only part of a four-system matrix. Add a native
aarch64 Linux runner (hosted or self-hosted) when claiming build support there;
do not silently substitute emulation for native validation.

The repository workflow uses a small native matrix and calls `./scripts/check`,
the same check entry point developers use. It also performs broad no-build
evaluation. Actions are pinned to full commit SHAs: a tag is mutable, while a
reviewed SHA is an immutable workflow dependency. Dependabot or Renovate can
propose SHA updates while retaining a comment with the human-readable version.

Set top-level `permissions: contents: read`, avoid `pull_request_target` for
building contribution code, and do not interpolate pull-request fields into
shell commands. Third-party actions execute with the job's token and secrets,
so pin and review them like source dependencies.

## Cachix: read everywhere, push only trusted results

A public cache can be configured read-only on pull requests without a secret.
Uploading requires a protected token and must occur only for trusted events.
A typical optional step is:

```yaml
- name: Configure Cachix
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  uses: cachix/cachix-action@<full-reviewed-commit-sha>
  with:
    name: example-cache
    authToken: ${{ secrets.CACHIX_AUTH_TOKEN }}
```

Do not copy this placeholder unchanged. Pin the current action commit after
review, create the repository secret outside version control, scope the token
to one cache, and protect the publication environment. Keep this credentialed
step out of workflows that run fork code. The checked-in workflow deliberately
contains no cache name, token, or publication step.

For stricter separation, let untrusted jobs build without credentials and let a
post-merge job rebuild the reviewed revision before pushing. Do not publish a
pull-request artifact merely because its build succeeded. Read-only cache
substitution and write authority are different capabilities.

## Attic pattern

Attic uses a server URL, cache name, public-key/substituter configuration for
consumers, and a login token for uploaders. A trusted publication job commonly
does the equivalent of:

```console
token_file="$RUNNER_TEMP/attic-token"
config_file="$RUNNER_TEMP/attic/config.toml"
install -m 0600 /dev/null "$token_file"
printf '%s' "$ATTIC_TOKEN" > "$token_file"
mkdir -p "$(dirname "$config_file")"
cat > "$config_file" <<EOF
default-server = "ci"
[servers.ci]
endpoint = "https://cache.example.invalid"
token-file = "$token_file"
EOF
export XDG_CONFIG_HOME="$RUNNER_TEMP"

check_path="$(
  nix build --no-link --print-out-paths \
    ".#checks.${SYSTEM}.package"
)"
attic push team-cache "$check_path"
rm -f "$token_file" "$config_file"
```

`example.invalid`, the token name, and the `package` check are placeholders.
Build concrete derivation-valued check attributes; the system-level
`checks.${SYSTEM}` set itself is not buildable. Supply the token through a
protected runtime secret and a mode-0600 token file, never through Nix strings,
derivations, flake inputs, command-line literals, or committed configuration.
Use a trap in production CI so temporary credentials are removed on failure.
Pin the Attic client version in a flake or action and configure the cache's
exact public key for readers. Treat self-hosted Attic as production
infrastructure: plan TLS, authentication, storage retention, garbage collection, backups, key rotation,
and upgrades.

If using an Attic GitHub Action, pin its full commit SHA and audit it. Calling a
pinned `attic` executable directly can make the trust and upload boundary
easier to inspect.

## Lock updates in CI

Normal CI must consume the committed `flake.lock`; it should not run
`nix flake update`. Network resolution during ordinary checks hides stale or
uncommitted pins. A separate scheduled or manually triggered update workflow
may:

1. update one named input;
2. record old and new revisions and transitive changes;
3. run broad evaluation and every native build/check matrix;
4. open a pull request with release notes and risk summary; and
5. require normal review before merge and cache publication.

Avoid combining unrelated input updates. Define an emergency process for
security fixes, an owner for failed updates, and a cadence that prevents giant
infrequent jumps. Reverting the lock-update commit provides a clear rollback.

## Failure diagnosis

- Foreign evaluation failure: inspect system guards and eager package imports.
- Native-only build failure: reproduce on that OS/architecture; evaluation was insufficient.
- Cache miss: inspect substituter URL, trusted public key, signatures, and whether the closure was uploaded.
- Secret unavailable on a fork PR: this is expected; redesign the job rather than weakening the boundary.
- Workflow SHA update: review the upstream diff between old and new commits before merging.

## Recap

Evaluate all declared systems, then build and test on matching native runners.
Run the repository's canonical checks, pin actions by SHA, keep pull requests
secret-free, and publish cache paths only from trusted reviewed revisions.

## Official links

- [Nix continuous integration](https://nix.dev/guides/continuous-integration)
- [`nix flake check`](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake-check)
- [GitHub Actions security hardening](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions)
- [Cachix CI](https://docs.cachix.org/continuous-integration-setup/github-actions)
- [Attic](https://docs.attic.rs/)
