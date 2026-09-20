{ lib, ... }:

{
  # TODO: declare options.lab.enable and options.lab.port.
  options.lab.message = lib.mkOption {
    type = lib.types.str;
    default = "add the remaining options";
  };
}
