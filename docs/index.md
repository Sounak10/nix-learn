# Nix, From First Principles

A practical guide to the Nix language, package manager, Nixpkgs, flakes, the
module system, NixOS, Home Manager, nix-darwin, and the machinery beneath
them.

This book develops one model throughout:

1. Nix expressions **evaluate** to ordinary values and derivation graphs.
2. Builders or substitutes **realize** immutable store objects.
3. Profiles and modules **compose** those objects into environments and
   systems.
4. Activation connects immutable results to a running, partly mutable world.

## Start learning

- New to Nix? Begin with [The Nix Concept Map](00-concept-map.md), then follow
  Part I in the sidebar.
- Writing software? Prioritize the language, builds, flakes, and Nixpkgs.
- Managing machines? Continue through modules, declarative systems, and
  operations.
- Debugging difficult behavior? Use the internals chapters and troubleshooting
  appendix.

## Run the labs

From the repository root:

```console
./scripts/lab
```

Inside the container:

```console
nix flake show
nix flake check
```

See the [Reading and Lab Guide](01-reading-and-lab-guide.md) for platform
labels, the experiment workflow, and Docker limitations.

!!! warning "Docker is not NixOS"

    The container is suitable for language, package-manager, flakes, and
    packaging labs. It is not a booted NixOS system. NixOS activation,
    hardware, system services, and some VM tests require a native Linux/NixOS
    environment with the capabilities identified by each chapter.

## What this guide covers

- Nix syntax, evaluation, laziness, purity, functions, and debugging.
- Store paths, derivations, builders, closures, profiles, roots, and garbage
  collection.
- Flake inputs, outputs, locks, schemas, registries, and legacy interoperation.
- Nixpkgs packaging, phases, dependencies, overlays, overrides, testing, and
  cross compilation.
- The module-system fixpoint, option types, merging, priorities, and reusable
  design.
- NixOS, Home Manager, nix-darwin, multi-host organization, CI, caches,
  distributed builds, Hydra, deployment, security, and internals.

Nix and Nixpkgs continue to evolve. The guide emphasizes durable concepts,
marks experimental and legacy interfaces, and links to primary documentation
for details that can change between releases.
