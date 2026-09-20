# Pure, tool-independent topology shared conceptually by both adapters.
# Hostnames use the reserved .invalid TLD and cannot be real destinations.
{
  canary = {
    hostname = "canary.ops.example.invalid";
    system = "x86_64-linux";
    cohort = "canary";
    tags = [
      "web"
      "canary"
    ];
  };

  web-a = {
    hostname = "web-a.ops.example.invalid";
    system = "x86_64-linux";
    cohort = "wave-1";
    tags = [
      "web"
      "wave-1"
    ];
  };

  web-b = {
    hostname = "web-b.ops.example.invalid";
    system = "x86_64-linux";
    cohort = "wave-2";
    tags = [
      "web"
      "wave-2"
    ];
  };
}
