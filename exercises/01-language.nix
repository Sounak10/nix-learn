# Replace each TODO without changing the result shape.
let
  double = number: number; # TODO: multiply by two
in
{
  greeting = "TODO";
  values = map double [
    1
    2
    3
  ];
}
