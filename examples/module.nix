{ lib, ... }:

{
  options.lab = {
    enable = lib.mkEnableOption "the example service";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port used by the example service.";
    };
  };

  config.lab.port = lib.mkIf true (lib.mkDefault 8080);
}
