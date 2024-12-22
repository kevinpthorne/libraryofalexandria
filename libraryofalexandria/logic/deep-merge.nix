# Merge multiple attribute sets, prioritizing earlier sets
# 
# example usage
# let
#   deepMerge = import ./logic/deep-merge.nix lib
#   attrSet1 = { a = 1; b = 2; c = { x = 3; y = 4; } };
#   attrSet2 = { b = 5; c = { y = 6; z = 7; } };
#   attrSet3 = { d = 8; c = { x = 9; } };
# in
#   deepMerge [ attrSet1 attrSet2 attrSet3 ];
# lib:
# let
#     merge = 
#         acc: new: lib.recursiveUpdate new acc;
# in
#     builtins.foldl' merge {}
lib:
with lib;
let
    recursiveMerge = attrList:
    let 
        f = attrPath:
            zipAttrsWith (n: values:
                if tail values == []
                    then head values
                else if all isList values
                    then unique (concatLists values)
                else if all isAttrs values
                    then f (attrPath ++ [n]) values
                else last values
            );
    in 
        f [] attrList;
in
    recursiveMerge