# let
#     # List all entries in a directory
#     allEntries = builtins.readDir "./clusters"; 

#     # Filter to include only directories
#     directories = builtins.filter (path: builtins.typeOf path == "path" && (builtins.pathExists (path + "/")) ) allEntries; 

#     # Get just the directory names
#     directoryNames = map (path: builtins.filePathToBaseName path) directories;
# in
# directoryNames
[
    "k"
]