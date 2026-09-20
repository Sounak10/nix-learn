{ pkgs }:

# TODO: add builder and args that create $out/message.txt.
derivation {
  name = "exercise-raw-derivation";
  system = pkgs.stdenv.hostPlatform.system;
  builder = "/TODO";
}
