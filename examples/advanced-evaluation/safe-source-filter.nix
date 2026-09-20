let
  source = builtins.path {
    path = ./fixtures;
    name = "advanced-evaluation-filtered-source";
    filter = path: type: type == "directory" || builtins.match ".*[.]txt" (baseNameOf path) != null;
  };
in
{
  storePath = toString source;
  files = builtins.attrNames (builtins.readDir source);
}
