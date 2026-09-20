{ ... }:

{
  # Illustrative virtual-disk facts make the configuration buildable. A real
  # host must use its generated hardware configuration instead.
  fileSystems."/".device = "/dev/vda1";
  boot.loader.grub.devices = [ "/dev/vda" ];

  services.hello-service = {
    enable = true;
    address = "0.0.0.0";
    port = 8080;
    greeting = "Hello from the example host!";
    openFirewall = true;
  };

  networking.hostName = "hello-example";
  system.stateVersion = "25.05";
}
