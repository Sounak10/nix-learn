final: prev: {
  nix-lab-hello = final.callPackage ./package.nix { };
  hello-with-overlay = prev.hello.overrideAttrs (old: {
    pname = "${old.pname}-nix-lab";
  });
}
