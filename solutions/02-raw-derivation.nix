{ pkgs }:

derivation {
  name = "exercise-raw-derivation";
  system = pkgs.stdenv.hostPlatform.system;
  builder = "${pkgs.bash}/bin/bash";
  PATH = "${pkgs.coreutils}/bin";
  args = [
    "-c"
    "mkdir -p $out; echo solved > $out/message.txt"
  ];
}
