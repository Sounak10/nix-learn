{ nixpkgs }:

let
  topology = import ./topology.nix;
in
builtins.mapAttrs (
  nodeName: node:
  nixpkgs.lib.nixosSystem {
    inherit (node) system;
    modules = [
      ./host-module.nix
      { networking.hostName = nodeName; }
    ];
  }
) topology
