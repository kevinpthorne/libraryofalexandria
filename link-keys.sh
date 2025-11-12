#!/bin/bash
set -eou pipefail

# A CLI to assist linking any keys specified in the project (but git-ignored) to /var/keys
# so colmena can upload them
#sudo ln -s $(pwd)/clusters/*/keys/token.key /var/keys/clusters/*/