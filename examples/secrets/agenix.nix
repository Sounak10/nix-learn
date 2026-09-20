{ config, pkgs, ... }:

{
  # Requires the upstream agenix NixOS module. The encrypted payload is
  # intentionally absent; create it with agenix after defining recipients.
  age = {
    identityPaths = [ "/var/lib/agenix/identity.age" ];
    secrets."example-service-token" = {
      file = ./service-token.age;
      owner = "example-service";
      group = "example-service";
      mode = "0400";
    };
  };

  users.groups.example-service = { };
  users.users.example-service = {
    isSystemUser = true;
    group = "example-service";
  };

  systemd.services.example-service = {
    description = "Inert agenix secret-path example";
    serviceConfig = {
      Type = "oneshot";
      User = "example-service";
      Group = "example-service";
      Environment = "SERVICE_TOKEN_FILE=${config.age.secrets."example-service-token".path}";
      # Test-only: checks readability without exposing secret contents.
      ExecStart = "${pkgs.runtimeShell} -c 'test -r \"$SERVICE_TOKEN_FILE\"'";
    };
  };
}
