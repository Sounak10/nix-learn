{ ... }:

{
  programs.hello-client = {
    enable = true;
    endpoint = "https://hello.example.org";
  };

  home = {
    username = "guide";
    homeDirectory = "/home/guide";
    stateVersion = "25.05";
  };
}
