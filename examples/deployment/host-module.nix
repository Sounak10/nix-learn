{ ... }:

{
  # Evaluation-only teaching host. It deliberately does not enable SSH,
  # install credentials, partition disks, or contact a network.
  boot.isContainer = true;

  systemd.services.deployment-example-health = {
    description = "Local health marker for deployment examples";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/run/current-system/sw/bin/true";
      RemainAfterExit = true;
    };
  };

  system.stateVersion = "25.11";
}
