# Part 10 — Practical Workflows

## Chapter 2: An End-to-End Service Project

**Platforms:** `[Linux]` `[macOS]` `[NixOS]` `[Docker]`

### Objectives

- Take one dependency-free program from source to package, checks, and apps.
- Reuse that package in NixOS, Home Manager, a VM test, and a
  Docker-compatible image archive.
- Separate safe local validation from platform-specific and deployment work.
- Keep secrets, network access, and host mutation outside default checks.

The companion project is in `projects/hello-service`. Run commands in this
chapter from that directory unless a command starts with `docker compose`.
Its Python HTTP server uses only the standard library and exposes:

- `GET /` for a JSON greeting;
- `GET /healthz` for a JSON readiness response;
- a `hello-client` command for querying either endpoint.

This is intentionally small application code. The purpose is to follow the
same artifact through Nix's package, module, test, image, user, and deployment
boundaries without hiding those boundaries behind a framework.

### Project map

```text
projects/hello-service/
├── flake.nix
├── flake.lock
├── package.nix
├── src/hello_service.py
├── tests/test_hello_service.py
└── nix/
    ├── nixos-module.nix
    ├── home-module.nix
    ├── vm-test.nix
    ├── example-host.nix
    └── example-home.nix
```

The nested flake is self-contained. It pins Nixpkgs and Home Manager, and Home
Manager follows the same Nixpkgs node to avoid a second, potentially
incompatible package set.

### Milestone 1: run the source tests

Enter the development shell and run the standard-library test suite:

```console
nix develop
python -m unittest discover -s tests -v
```

The shell supplies Python and the Nix formatter. `PYTHONPATH` points at `src`
only for the interactive shell; the package itself does not rely on the source
checkout. The tests start a server on an ephemeral loopback port, check the
root and health routes, check a 404, and parse a temporary client
configuration. They neither contact the public network nor use credentials.

### Milestone 2: package and run it

`package.nix` installs the source under `$out/libexec` and creates two wrapped
executables. The wrappers use the exact Python interpreter from Nixpkgs, so
there is no `/usr/bin/env python` runtime dependency.

```console
nix build
./result/bin/hello-service
```

In another terminal:

```console
./result/bin/hello-client
./result/bin/hello-client --health
```

The flake exposes the same package through apps:

```console
nix run
nix run .#client -- --endpoint http://127.0.0.1:8080 --health
```

`nix run` listens only on loopback by default. Binding to a public interface is
a separate operational decision.

### Milestone 3: make checks the default gate

Run:

```console
nix flake check --print-build-logs
```

The host-system checks:

1. build the package;
2. run all Python tests;
3. check Nix formatting and Python syntax;
4. on Linux, evaluate the NixOS module and force representative option and
   systemd-unit values.

These checks use no fixed-output downloads beyond locked flake inputs, so
there are no placeholder or fake hashes. They do not start QEMU, build the Docker
image, connect to a host, or activate a configuration. This keeps the default
gate useful in an unprivileged Linux container and on macOS.

Use the repository's Docker lab for a clean Linux run:

```console
docker compose build lab
docker compose run --rm \
  -w /workspace/projects/hello-service \
  lab flake check --print-build-logs
docker compose run --rm \
  -w /workspace/projects/hello-service \
  lab build
```

Those commands write only to the mounted project and Docker-managed Nix
volumes. They do not alter the host's NixOS configuration. The lock file also
means normal checks do not need to discover newer dependency revisions.

### Milestone 4: expose a typed NixOS service

`nix/nixos-module.nix` exports `services.hello-service` with typed options:

- `enable`: Boolean;
- `package`: package;
- `address`: non-empty string;
- `port`: TCP/UDP port range;
- `greeting`: non-empty string;
- `openFirewall`: Boolean.

The firewall defaults to closed. An assertion rejects opening the firewall
for common loopback literals such as `localhost`, `127.0.0.0/8`, and `::1`.
DNS resolution remains an operational concern. The greeting is explicitly public
configuration: putting a password or token there would expose it through the
Nix store and process command line.

The generated systemd unit uses a dynamic user, an empty capability set,
read-only system paths, private devices and temporary files, kernel and
namespace protections, restricted network address families, and restart-on-
failure behavior. Hardening is tested with the actual service because a
restriction that an application cannot tolerate is not useful hardening.

A consumer imports the exported module:

```nix
{
  imports = [ inputs.hello-service.nixosModules.default ];

  services.hello-service = {
    enable = true;
    address = "0.0.0.0";
    port = 8080;
    greeting = "Hello from this host!";
    openFirewall = true;
  };
}
```

`nixosConfigurations.hello-example` composes the included example host. It is
an evaluation and build target, not an activation instruction:

```console
nix eval .#nixosConfigurations.hello-example.config.services.hello-service.port
nix build .#nixosConfigurations.hello-example.config.system.build.toplevel
```

Building a toplevel creates a store result but does not switch, boot, or mutate
a running NixOS system.

### Milestone 5: test the running NixOS integration

The optional VM test boots NixOS, waits for the systemd unit and port, and
checks both HTTP routes:

```console
nix build .#vm-test --print-build-logs
```

This target is Linux-only and deliberately is not in `checks`. It needs QEMU
and is substantially heavier than package and evaluation tests. The test
derivation from this pinned Nixpkgs advertises the `kvm` required system
feature, so its runner must provide `/dev/kvm` and enable that Nix feature.
The unprivileged Docker lab can evaluate the test and build its guest and test
driver, but cannot execute the final target without KVM passthrough. It is not
part of the Docker-safe baseline.

The VM proves that the package, NixOS module, systemd unit, firewall policy,
and HTTP process work together. It does not prove physical-host boot,
production capacity, or remote rollout safety.

### Milestone 6: build a Docker-compatible image

On Linux:

```console
nix build .#docker-image
docker load < result
docker run --rm -p 127.0.0.1:8080:8080 hello-service:1.0.0
```

The build itself is daemonless: `dockerTools.buildLayeredImage` constructs a
Docker image archive without contacting Docker. It uses standard OCI label
names, but the archive is not an OCI image-layout archive. Loading and running
the archive are optional runtime steps and require Docker or a compatible tool.
The published port is bound to host loopback in the example.

The image contains the same package used by the local app and NixOS module.
Its default command binds to `0.0.0.0` inside the container, while the runtime
decides whether and where to publish that port.

### Milestone 7: provide a Home Manager client

The Home Manager module is client-shaped: it installs `hello-client` and writes
only a public endpoint to
`$XDG_CONFIG_HOME/hello-service/config.json`. It does not try to run a system
daemon from a user session and it does not accept credentials.

```nix
{
  imports = [ inputs.hello-service.homeModules.default ];
  programs.hello-client = {
    enable = true;
    endpoint = "https://hello.example.org";
  };
}
```

The flake includes Linux and macOS examples. Build their activation packages
without activating either:

```console
nix build '.#homeConfigurations."guide@linux".activationPackage'
nix build '.#homeConfigurations."guide@macos".activationPackage'
```

Build the configuration matching the current platform. The macOS output
demonstrates evaluation and user-level packaging; it is not a nix-darwin
system configuration and does not manage launchd or macOS settings.

### Milestone 8: inspect, do not deploy

Deployment tools eventually need a host inventory, transport identity,
authorization, rollout policy, and rollback plan. Those are intentionally not
invented here. The flake instead exposes inert deployment metadata:

```console
nix build .#deployment-plan
cat result
nix run .#inspect-deployment
```

The JSON names the example toplevel attribute and a placeholder inventory
target. It contains no hostname credential, private key, token, activation
command, SSH invocation, or write operation.

For a real remote rollout, first evaluate and build locally or on an approved
builder, then choose a deployment tool and a real inventory outside this
tutorial. Do not paste secrets into flake arguments, module strings, generated
files, or command lines. A remote `switch`, `boot`, or profile update is a
separate privileged milestone with an out-of-band recovery plan.

### Validation matrix

- **Docker-safe default:** `nix flake check`, package build, app packaging,
  module evaluation, deployment-plan inspection.
- **Optional Linux:** NixOS toplevel build, VM test, Docker image build, image
  load/run.
- **Optional remote environment:** inventory validation and deployment only
  after credentials, authorization, rollback, and host policy exist.
- **Optional macOS:** package, client app, checks, formatter, development
  shell, and macOS Home Manager activation-package build. NixOS VM and Docker
  outputs are intentionally absent there.

Keep those lanes separate in CI. Fast deterministic checks should gate every
change; architecture-specific image and VM jobs should run on matching Linux
workers; deployment should consume already reviewed outputs and require an
explicit environment approval.

### Recap

One package can serve several consumers without conflating them. Apps are
developer entry points, checks are the portable gate, NixOS and Home Manager
modules are typed integration APIs, VM tests verify runtime composition,
Docker image archives serve container runtimes, and deployment metadata is not
deployment.
The lock file pins dependency identity; it does not remove the need for
runtime security and rollout discipline.

### Exercises

1. Add a typed `requestTimeout` client option without putting it in the server.
2. Add an HTTP response test while keeping the default checks network-isolated.
3. Add a second Linux architecture to CI and identify which outputs must run
   natively.
4. Design a secret-delivery interface for an authenticated version without
   placing secret values in the Nix store.

### Official links

- [Nix flake checks](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake-check)
- [NixOS module system](https://nixos.org/manual/nixos/stable/#sec-writing-modules)
- [NixOS tests](https://nixos.org/manual/nixos/stable/#sec-nixos-tests)
- [Nixpkgs Docker tools](https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-dockerTools)
- [Home Manager manual](https://nix-community.github.io/home-manager/)
- [systemd service hardening](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html)
