{ lib, pkgs, ... }:

{
  networking.hostName = "nix-lab";
  system.stateVersion = "25.11";

  environment.systemPackages = [ pkgs.hello ];
  services.getty.autologinUser = lib.mkDefault "root";
}
