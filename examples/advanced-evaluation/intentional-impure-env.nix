# INTENTIONAL IMPURITY: run only with --impure.
# The result depends on process state that is not a declared Nix input.
let
  value = builtins.getEnv "ADVANCED_EVAL_MESSAGE";
in
{
  message = if value == "" then "<unset>" else value;
}
