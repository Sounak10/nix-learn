{
  description = "Runnable, cross-system Nix learning lab";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/b6018f87da91d19d0ab4cf979885689b469cdd41";

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems =
        function:
        lib.genAttrs systems (
          system:
          function (
            import nixpkgs {
              inherit system;
              overlays = [ (import ./examples/overlay.nix) ];
            }
          )
        );

      language = import ./examples/language.nix;
      evaluatedModule = lib.evalModules {
        modules = [
          ./examples/module.nix
          { lab.enable = true; }
        ];
      };
      evaluatedHome = lib.evalModules {
        modules = [ ./examples/home-manager-shaped.nix ];
      };
      evaluatedNixos = lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./examples/nixos.nix ];
      };
    in
    {
      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            bashInteractive
            nixfmt-rfc-style
          ];
          shellHook = ''
            echo "Nix lab: run ./scripts/check when ready."
          '';
        };
      });

      packages = forAllSystems (
        pkgs:
        let
          hello = pkgs.callPackage ./examples/package.nix { };
          app = pkgs.callPackage ./examples/app.nix { };
        in
        {
          inherit app;
          default = hello;
          hello = hello;
          raw-derivation = import ./examples/raw-derivation.nix { inherit pkgs; };
          overlay-hello = pkgs.nix-lab-hello;
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          nixos-test = import ./examples/nixos-test.nix { inherit pkgs; };
        }
      );

      apps = forAllSystems (
        pkgs:
        let
          app = pkgs.callPackage ./examples/app.nix { };
          hello = pkgs.callPackage ./examples/package.nix { };
        in
        {
          default = {
            type = "app";
            program = "${app}/bin/nix-lab-app";
            meta.description = "Run the Nix lab example application";
          };
          app = {
            type = "app";
            program = "${app}/bin/nix-lab-app";
            meta.description = "Run the Nix lab example application";
          };
          hello = {
            type = "app";
            program = "${hello}/bin/nix-lab-hello";
            meta.description = "Run the Nix lab hello package";
          };
        }
      );

      checks = forAllSystems (
        pkgs:
        let
          app = pkgs.callPackage ./examples/app.nix { };
          hello = pkgs.callPackage ./examples/package.nix { };
          raw = import ./examples/raw-derivation.nix { inherit pkgs; };
          solvedLanguage = import ./solutions/01-language.nix;
          solvedRaw = import ./solutions/02-raw-derivation.nix { inherit pkgs; };
          solvedPackageApp = pkgs.callPackage ./solutions/03-package-app.nix { };
          solvedOverlayPkgs = pkgs.extend (import ./solutions/04-overlay.nix);
          solvedModule = lib.evalModules {
            modules = [ ./solutions/05-module.nix ];
          };
          solvedHome = lib.evalModules {
            modules = [ ./solutions/06-home-manager-shaped.nix ];
          };
          syntax =
            pkgs.runCommand "nix-lab-syntax"
              {
                nativeBuildInputs = [ pkgs.nixfmt-rfc-style ];
                src = self;
              }
              ''
                while IFS= read -r file; do
                  nixfmt --check "$file"
                done < <(find "$src"/examples "$src"/exercises "$src"/solutions \
                  -type f -name '*.nix' -print)
                touch "$out"
              '';
          evaluation =
            assert language.greeting == "hello, NIX!";
            assert solvedLanguage.greeting == "hello, nix";
            assert
              solvedLanguage.values == [
                2
                4
                6
              ];
            assert evaluatedModule.config.lab.port == 8080;
            assert evaluatedHome.config.programs.git.enable;
            assert solvedModule.config.lab.enable;
            assert solvedHome.config.home.username == "learner";
            assert solvedHome.config.programs.git.enable;
            assert solvedOverlayPkgs.nix-lab-hello.pname == "nix-lab-hello";
            pkgs.runCommand "nix-lab-evaluation" { } "touch $out";
        in
        {
          inherit
            syntax
            evaluation
            hello
            app
            raw
            ;
          solution-raw = solvedRaw;
          solution-package = solvedPackageApp.package;
          solution-app = solvedPackageApp.app;
          solution-overlay = solvedOverlayPkgs.nix-lab-hello;
          overlay = pkgs.nix-lab-hello;
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          solution-nixos-evaluation =
            let
              solvedNixos = lib.nixosSystem {
                system = pkgs.stdenv.hostPlatform.system;
                modules = [ ./solutions/07-nixos.nix ];
              };
            in
            assert solvedNixos.config.networking.hostName == "solved-nix-lab";
            assert solvedNixos.config.system.stateVersion == "25.11";
            pkgs.runCommand "nix-lab-solution-nixos-evaluation" { } "touch $out";
        }
      );

      lib = {
        languageResult = language.greeting;
        moduleResult = evaluatedModule.config.lab;
        homeManagerResult = evaluatedHome.config;
        nixosEvaluations.x86_64-linux = {
          hostName = evaluatedNixos.config.networking.hostName;
          stateVersion = evaluatedNixos.config.system.stateVersion;
        };
      };
    };
}
