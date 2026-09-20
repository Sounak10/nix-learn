let
  records = [
    {
      name = "alpha";
      enabled = true;
    }
    {
      name = "beta";
      enabled = false;
    }
    {
      name = "gamma";
      enabled = true;
    }
  ];
in
{
  enabledNames = map (record: record.name) (builtins.filter (record: record.enabled) records);
  total = builtins.length records;
}
