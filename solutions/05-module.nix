{ lib, ... }:

{
  options.lab = {
    enable = lib.mkEnableOption "the lab";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };
  };

  config.lab.enable = lib.mkDefault true;
}
