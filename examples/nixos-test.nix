{ pkgs }:

# Evaluation/build works on Linux. Running the VM needs Linux with KVM available;
# Docker Desktop on macOS does not expose the required nested KVM acceleration.
pkgs.testers.runNixOSTest {
  name = "nix-lab-smoke";

  nodes.machine = { ... }: {
    imports = [ ./nixos.nix ];
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("hello | grep -q Hello")
  '';
}
