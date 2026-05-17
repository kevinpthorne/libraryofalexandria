#!/usr/bin/env nix-shell
#!nix-shell -i bash -p openssl

set -eou pipefail

# A CLI to assist linking any keys specified in the project (but git-ignored) to /var/keys
# so colmena can upload them
for src in $(pwd)/clusters/*/keys/*; do
    # 1. Safety check: If no files exist, skip to prevent errors
    [ -e "$src" ] || continue
    
    # 2. Extract names using native Bash parameter expansion (much faster)
    keyfile="${src##*/}"           # Strips everything up to the last '/'
    base_path="${src%/*/*}"        # Strips '/keys/keyfile' from the end
    cluster="${base_path##*/}"     # Strips everything up to the last '/' of the base path
    
    target="/var/keys/clusters/$cluster/$keyfile"
    
    # 3. If the target already exists (or is a broken symlink), skip to the next file
    if [ -e "$target" ] || [ -L "$target" ]; then
        echo "Target $target already exists, skipping..."
        continue
    fi
    
    # 4. Create target directory and symlink
    mkdir -p "/var/keys/clusters/$cluster"
    sudo ln -s "$src" "$target"
    echo "Linked $src -> $target"
done