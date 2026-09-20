{
  pkgs,
  helloPackage,
  helloModule,
}:

pkgs.testers.runNixOSTest {
  name = "hello-service";

  nodes.server =
    { pkgs, ... }:
    {
      imports = [ helloModule ];
      environment.systemPackages = [ pkgs.curl ];
      services.hello-service = {
        enable = true;
        package = helloPackage;
        address = "0.0.0.0";
        port = 8080;
        greeting = "Hello from the VM test!";
        openFirewall = true;
      };
    };

  testScript = ''
    start_all()
    server.wait_for_unit("hello-service.service")
    server.wait_for_open_port(8080)
    server.succeed(
      "curl --fail --silent http://127.0.0.1:8080/healthz "
      "| grep --fixed-strings '\"status\": \"ok\"'"
    )
    server.succeed(
      "curl --fail --silent http://127.0.0.1:8080/ "
      "| grep --fixed-strings 'Hello from the VM test!'"
    )
  '';
}
