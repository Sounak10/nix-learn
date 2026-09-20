{ stdenvNoCC, writeShellApplication }:

{
  # TODO: install an executable under $out/bin with mkDerivation.
  package = stdenvNoCC.mkDerivation {
    name = "exercise-package";
    dontUnpack = true;
    installPhase = "mkdir -p $out";
  };

  # TODO: make this print a useful message.
  app = writeShellApplication {
    name = "exercise-app";
    text = "true";
  };
}
