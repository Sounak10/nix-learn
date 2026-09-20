{ lib, ... }:

{
  # This mirrors Home Manager's option shape without adding it as a dependency.
  options.home.username = lib.mkOption { type = lib.types.str; };

  # TODO: declare home.homeDirectory, home.stateVersion, and programs.git.enable.
  config.home.username = "learner";
}
