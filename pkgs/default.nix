nixpkgs:
args:
let
    folderContents = builtins.readDir ./.;
    folderDirectories = nixpkgs.lib.filterAttrs (
        path: type: (type == "directory") && !(nixpkgs.lib.strings.hasPrefix "_" path)
    ) folderContents;
    localPkgs = prev: nixpkgs.lib.mapAttrs (path: _type: import ./${path} args) folderDirectories;
    # overlay = nixpkgs.lib.mapAttrsToList (path: _type: import ./${path} args) folderDirectories;
in
localPkgs
# overlay