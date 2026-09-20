let
  double = number: number * 2;
in
{
  greeting = "hello, nix";
  values = map double [
    1
    2
    3
  ];
}
