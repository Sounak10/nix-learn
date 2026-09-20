# INTENTIONAL FAILURE under --restrict-eval.
# This host path is not a declared input and must not be used in real builds.
builtins.readFile /etc/hosts
