{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.hello-client;
  packageDefault = pkgs.callPackage ../package.nix { };
in
{
  options.programs.hello-client = {
    enable = lib.mkEnableOption "the hello-service command-line client";

    package = lib.mkOption {
      type = lib.types.package;
      default = packageDefault;
      defaultText = lib.literalExpression "pkgs.callPackage ./package.nix { }";
      description = "Package providing the hello-client executable.";
    };

    endpoint = lib.mkOption {
      type = lib.types.strMatching "https?://.+";
      default = "http://127.0.0.1:8080";
      example = "https://hello.example.org";
      description = "Default public HTTP(S) endpoint queried by hello-client.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
    xdg.configFile."hello-service/config.json".text = builtins.toJSON {
      inherit (cfg) endpoint;
    };
  };
}
