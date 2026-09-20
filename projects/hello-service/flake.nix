{
  description = "A dependency-free service project for the Nix guide";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
    }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs systems;
      pkgsFor = system: import nixpkgs { inherit system; };
      helloFor = system: (pkgsFor system).callPackage ./package.nix { };

      deploymentPlan =
        system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.writeText "hello-service-deployment-plan.json" (
          builtins.toJSON {
            target = "replace-with-an-inventory-host";
            output = "nixosConfigurations.hello-example.config.system.build.toplevel";
            activation = "intentionally omitted";
            note = "This artifact describes a target and never connects to or changes a host.";
          }
        );
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          hello = helloFor system;
        in
        {
          default = hello;
          hello-service = hello;
          deployment-plan = deploymentPlan system;
        }
        // lib.optionalAttrs pkgs.stdenv.isLinux {
          docker-image = pkgs.dockerTools.buildLayeredImage {
            name = "hello-service";
            tag = "1.0.0";
            contents = [ hello ];
            config = {
              Cmd = [ "${hello}/bin/hello-service" ];
              ExposedPorts."8080/tcp" = { };
              Env = [
                "HELLO_ADDRESS=0.0.0.0"
                "HELLO_PORT=8080"
              ];
              Labels = {
                "org.opencontainers.image.title" = "hello-service";
                "org.opencontainers.image.version" = "1.0.0";
              };
            };
          };

          vm-test = import ./nix/vm-test.nix {
            inherit pkgs;
            helloPackage = hello;
            helloModule = self.nixosModules.hello-service;
          };
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          hello = helloFor system;
          inspectPlan = pkgs.writeShellApplication {
            name = "inspect-hello-deployment";
            text = ''
              cat ${deploymentPlan system}
            '';
          };
        in
        {
          default = {
            type = "app";
            program = "${hello}/bin/hello-service";
            meta.description = "Run the hello-service HTTP server";
          };
          client = {
            type = "app";
            program = "${hello}/bin/hello-client";
            meta.description = "Query a running hello-service instance";
          };
          inspect-deployment = {
            type = "app";
            program = "${inspectPlan}/bin/inspect-hello-deployment";
            meta.description = "Inspect the inert deployment plan";
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          hello = helloFor system;
          evaluatedModule = lib.optionalAttrs pkgs.stdenv.isLinux (
            let
              evaluated = lib.nixosSystem {
                inherit system;
                modules = [
                  self.nixosModules.hello-service
                  {
                    services.hello-service.enable = true;
                    system.stateVersion = "25.05";
                  }
                ];
              };
            in
            {
              module-evaluation = pkgs.runCommand "hello-module-evaluation" {
                servicePort = toString evaluated.config.services.hello-service.port;
                unit = evaluated.config.systemd.services.hello-service.description;
              } "touch $out";
            }
          );
        in
        {
          package = hello;

          unit-tests =
            pkgs.runCommand "hello-service-unit-tests"
              {
                nativeBuildInputs = [ pkgs.python3 ];
              }
              ''
                export PYTHONPATH=${./src}
                python -m unittest discover -s ${./tests} -v
                touch $out
              '';

          formatting =
            pkgs.runCommand "hello-service-formatting"
              {
                nativeBuildInputs = [ pkgs.nixfmt-rfc-style ];
              }
              ''
                nixfmt --check \
                  ${./flake.nix} \
                  ${./package.nix} \
                  ${./nix/example-home.nix} \
                  ${./nix/example-host.nix} \
                  ${./nix/home-module.nix} \
                  ${./nix/nixos-module.nix} \
                  ${./nix/vm-test.nix}
                export PYTHONPYCACHEPREFIX="$TMPDIR/pycache"
                ${pkgs.python3}/bin/python -m py_compile \
                  ${./src}/hello_service.py ${./tests}/test_hello_service.py
                touch $out
              '';
        }
        // evaluatedModule
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.python3
              pkgs.nixfmt-rfc-style
            ];
            shellHook = ''
              export PYTHONPATH="$PWD/src''${PYTHONPATH:+:$PYTHONPATH}"
            '';
          };
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt-rfc-style);

      nixosModules = {
        hello-service = import ./nix/nixos-module.nix;
        default = self.nixosModules.hello-service;
      };

      homeModules = {
        hello-client = import ./nix/home-module.nix;
        default = self.homeModules.hello-client;
      };

      nixosConfigurations.hello-example = lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.nixosModules.hello-service
          ./nix/example-host.nix
        ];
      };

      homeConfigurations = {
        "guide@linux" = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor "x86_64-linux";
          modules = [
            self.homeModules.hello-client
            ./nix/example-home.nix
          ];
        };
        "guide@macos" = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor "aarch64-darwin";
          modules = [
            self.homeModules.hello-client
            (lib.recursiveUpdate (import ./nix/example-home.nix { }) {
              home.homeDirectory = "/Users/guide";
            })
          ];
        };
      };
    };
}
