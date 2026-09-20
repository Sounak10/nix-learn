# Equivalent Colmena hive for the topology in topology.nix.
# Colmena itself is required only when applying this returned hive.
{ nixpkgs }:

let
  topology = import ./topology.nix;
in
{
  meta = {
    nixpkgs = import nixpkgs { system = "x86_64-linux"; };
  };

  defaults =
    { ... }:
    {
      imports = [ ./host-module.nix ];
      deployment = {
        targetUser = "deploy";
      };
    };
}
// builtins.mapAttrs (
  name: node:
  { ... }:
  {
    networking.hostName = name;
    deployment = {
      targetHost = node.hostname;
      tags = node.tags;
    };
  }
) topology
