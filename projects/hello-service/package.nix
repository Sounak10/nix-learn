{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
}:

stdenvNoCC.mkDerivation {
  pname = "hello-service";
  version = "1.0.0";

  src = ./src;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm644 hello_service.py $out/libexec/hello-service/hello_service.py

    makeWrapper ${lib.getExe python3} $out/bin/hello-service \
      --add-flags "$out/libexec/hello-service/hello_service.py serve"
    makeWrapper ${lib.getExe python3} $out/bin/hello-client \
      --add-flags "$out/libexec/hello-service/hello_service.py client"
    runHook postInstall
  '';

  meta = {
    description = "Dependency-free example HTTP service for the Nix guide";
    license = lib.licenses.mit;
    mainProgram = "hello-service";
    platforms = lib.platforms.unix;
  };
}
