final: prev: {
  nix-lab-hello = final.callPackage ../examples/package.nix { };
  unchanged-hello = prev.hello;
}
