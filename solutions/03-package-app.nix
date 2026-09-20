{ stdenvNoCC, writeShellApplication }:

{
  package = stdenvNoCC.mkDerivation {
    name = "exercise-package";
    dontUnpack = true;
    installPhase = ''
      mkdir -p "$out/bin"
      printf '#!/bin/sh\necho packaged\n' > "$out/bin/exercise-package"
      chmod +x "$out/bin/exercise-package"
    '';
  };

  app = writeShellApplication {
    name = "exercise-app";
    text = "echo solved app";
  };
}
