{ lib, config, ... }:

let
  cfg = config.lab;
in
{
  options.lab = {
    runtimeSecretFile = lib.mkOption {
      type = lib.types.str;
      example = "/run/secrets/example-service-token";
      description = ''
        Runtime path materialized by a secrets manager. Use a string, not a Nix
        path: a Nix path could copy plaintext into the world-readable store.
      '';
    };

    serviceEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      description = "Non-secret environment containing only secret file paths.";
    };
  };

  config.lab.serviceEnvironment = {
    SERVICE_TOKEN_FILE = cfg.runtimeSecretFile;
  };
}
