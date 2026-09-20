{ pkgs, ... }:

{
  # TODO: set networking.hostName and system.stateVersion.
  environment.systemPackages = [ pkgs.hello ];
}
