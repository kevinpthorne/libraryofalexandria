# Conditionally import a module if a path exists, else return empty attrset
# currently tied to having 2 arguments since nix doesn't provide a good
# way to do function recursion outside of recursive sets
#
# Also, default.nix will need to be specified directly if using
#
# example usage
# let
#   importIfExists = import ./logic/import-if-exists.nix
#   myConditionalImport = importIfExists ./path/to/somewhere.nix {} {}
# in
#    # ....
path: config: moduleArgs:
if (builtins.pathExists path) then import path config moduleArgs else {}