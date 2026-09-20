{
  description = "Evaluation-only macOS learning configuration";

  inputs = {
    # Exact revisions keep this example pinned even before a lock file exists.
    nixpkgs.url = "github:NixOS/nixpkgs/a32edd7654519351e48e80372a928df336394670";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/d2a22a3659a6ae99847ea9176114f6957b8ac62e";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      ...
    }:
    let
      system = "aarch64-darwin";
      hostName = "example-mac";
      userName = "example";

      pkgs = import nixpkgs {
        inherit system;
      };

      standaloneHome = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit inputs hostName userName;
        };
        modules = [ ./home.nix ];
      };

      darwinHost = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs hostName userName;
        };
        modules = [
          home-manager.darwinModules.home-manager
          ./configuration.nix
        ];
      };
    in
    {
      # Both outputs use placeholders and are intended for evaluation/building.
      darwinConfigurations.${hostName} = darwinHost;
      homeConfigurations."${userName}@${hostName}" = standaloneHome;

      # `nix flake check` builds these but never runs either activation program.
      checks.${system} = {
        darwin-system = darwinHost.system;
        home-activation = standaloneHome.activationPackage;
      };
    };
}
