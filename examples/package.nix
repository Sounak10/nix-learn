{ stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "nix-lab-hello";
  version = "1.0.0";
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    cat > "$out/bin/nix-lab-hello" <<'SCRIPT'
    #!/bin/sh
    echo "hello from mkDerivation"
    SCRIPT
    chmod +x "$out/bin/nix-lab-hello"
    runHook postInstall
  '';
}
