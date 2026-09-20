{
  inputs,
  pkgs,
  hostName,
  userName,
  ...
}:
{
  # This module describes a host but performs no activation by itself.
  nixpkgs.hostPlatform = "aarch64-darwin";
  networking.hostName = hostName;

  # Required by user-scoped nix-darwin options. This does not create the user.
  system.primaryUser = userName;
  users.users.${userName}.home = "/Users/${userName}";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages = with pkgs; [
    git
    jq
    ripgrep
  ];

  programs.zsh.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs hostName userName;
    };
    users.${userName} = import ./home.nix;
  };

  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

  # Compatibility version, not the nix-darwin package version.
  system.stateVersion = 7;
}
