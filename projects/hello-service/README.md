# hello-service

This directory is the runnable companion to the guide's end-to-end service
chapter. The service and client use only Python's standard library; Nix supplies
the interpreter, packaging, checks, modules, VM test, and Docker-compatible
image archive.

From this directory:

```console
nix flake check
nix run
nix run .#client -- --health
nix build .#docker-image    # Linux only
nix build .#vm-test         # optional; Linux, QEMU, /dev/kvm, and Nix kvm feature
```

`nix run` listens on `127.0.0.1:8080` by default. Configuration contains no
credentials. The `deployment-plan` output is inert JSON and activation is
deliberately outside this example.
