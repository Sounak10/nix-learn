{ pkgs }:

derivation {
  name = "raw-derivation-lab";
  system = pkgs.stdenv.hostPlatform.system;
  builder = "${pkgs.bash}/bin/bash";
  PATH = "${pkgs.coreutils}/bin";
  args = [
    "-c"
    ''
      mkdir -p "$out"
      printf '%s\n' 'built with derivation' > "$out/message.txt"
    ''
  ];
}
