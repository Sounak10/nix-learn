{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.hello-service;
  isLoopbackLiteral =
    lib.hasPrefix "127." cfg.address
    || builtins.elem cfg.address [
      "localhost"
      "localhost.localdomain"
      "::1"
      "0:0:0:0:0:0:0:1"
    ];
in
{
  options.services.hello-service = {
    enable = lib.mkEnableOption "the hello-service example daemon";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ./package.nix { }";
      description = "Package providing the hello-service executable.";
    };

    address = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "127.0.0.1";
      description = "Address on which the service listens.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "TCP port on which the service listens.";
    };

    greeting = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "Hello from NixOS!";
      description = "Public greeting returned by the service; do not put secrets here.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the configured TCP port in the NixOS firewall.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.openFirewall -> !isLoopbackLiteral;
        message = "services.hello-service.openFirewall requires a non-loopback address literal.";
      }
    ];

    networking.firewall.allowedTCPPorts = lib.optional cfg.openFirewall cfg.port;

    systemd.services.hello-service = {
      description = "Nix guide hello service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = lib.escapeShellArgs [
          "${cfg.package}/bin/hello-service"
          "--address"
          cfg.address
          "--port"
          (toString cfg.port)
          "--greeting"
          cfg.greeting
        ];
        Restart = "on-failure";
        RestartSec = "2s";
        DynamicUser = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
      };
    };
  };
}
