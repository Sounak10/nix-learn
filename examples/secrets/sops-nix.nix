{ config, pkgs, ... }:

{
  # Requires the upstream sops-nix NixOS module. The referenced encrypted file
  # is intentionally absent from this teaching repository.
  sops = {
    defaultSopsFile = ./secrets.yaml;
    defaultSopsFormat = "yaml";

    # This persistent age identity must be provisioned out of band. It must
    # never be represented by a Nix path or committed to source control.
    age.keyFile = "/var/lib/sops-nix/key.txt";
    age.generateKey = false;

    secrets."example-service/token" = {
      owner = "example-service";
      group = "example-service";
      mode = "0400";
      restartUnits = [ "example-service.service" ];
    };
  };

  users.groups.example-service = { };
  users.users.example-service = {
    isSystemUser = true;
    group = "example-service";
  };

  systemd.services.example-service = {
    description = "Inert secret-path example";
    serviceConfig = {
      Type = "oneshot";
      User = "example-service";
      Group = "example-service";
      Environment = "SERVICE_TOKEN_FILE=${config.sops.secrets."example-service/token".path}";
      # Test-only: verifies that the runtime file exists without reading or
      # logging its contents. Replace with the real packaged service.
      ExecStart = "${pkgs.runtimeShell} -c 'test -r \"$SERVICE_TOKEN_FILE\"'";
    };
  };
}
