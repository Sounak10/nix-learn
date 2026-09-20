{ pkgs, ... }:

{
  networking.hostName = "solved-nix-lab";
  system.stateVersion = "25.11";
  environment.systemPackages = [ pkgs.hello ];
}
