#!/bin/sh
set -xeu
# set -o pipefail

nix build '.#nixosConfigurations.libraryofalexandria-k-master0-rpi.config.system.build.sdImage' --show-trace
nix build '.#nixosConfigurations.libraryofalexandria-k-master1-rpi.config.system.build.sdImage' --show-trace
nix build '.#nixosConfigurations.libraryofalexandria-k-worker0-rpi.config.system.build.sdImage' --show-trace
nix build '.#nixosConfigurations.libraryofalexandria-k-worker1-rpi.config.system.build.sdImage' --show-trace
nix build '.#nixosConfigurations.libraryofalexandria-k-worker2-rpi.config.system.build.sdImage' --show-trace
