{ writeShellApplication }:

writeShellApplication {
  name = "nix-lab-app";
  text = ''
    echo "nix lab app"
  '';
}
