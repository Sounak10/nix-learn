# Pure deploy-rs topology adapter. Supply the upstream
# deploy-rs.lib.<system>.activate.nixos function as activateNixos.
{
  activateNixos,
  nixosConfigurations,
}:

let
  topology = import ./topology.nix;
in
{
  nodes = builtins.mapAttrs (name: node: {
    hostname = node.hostname;
    sshUser = "deploy";
    user = "root";
    autoRollback = true;
    magicRollback = true;
    confirmTimeout = 60;

    profiles.system = {
      path = activateNixos nixosConfigurations.${name};
      groups = node.tags;
    };
  }) topology;
}
