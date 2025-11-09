# Conditionally import a module if a path exists, else return empty attrset.
# nixosModules seems to accept an empty attrset when included in the 
# `modules` value of a nixosSystem.
#
# Also, default.nix will need to be specified directly if using
#
# example usage
# let
#   importIfExists = import ./logic/import-if-exists.nix
#   myConditionalImport = importIfExists ./path/to/somewhere.nix
# in
#    # ....
path: args:
if (builtins.pathExists path) then import path args else {}