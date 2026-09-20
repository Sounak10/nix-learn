{ lib, ... }:

{
  options = {
    home.username = lib.mkOption { type = lib.types.str; };
    home.homeDirectory = lib.mkOption { type = lib.types.str; };
    home.stateVersion = lib.mkOption { type = lib.types.str; };
    programs.git.enable = lib.mkEnableOption "Git";
  };

  config = {
    home.username = "learner";
    home.homeDirectory = "/home/learner";
    home.stateVersion = "25.11";
    programs.git.enable = true;
  };
}
