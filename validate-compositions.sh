#!/bin/bash
set -e

# Ensure functions.yaml exists in the current directory or point to a shared one
FUNCTIONS_FILE="apps/loa-core/templates/crossplane/pkgs/functions.yml"
export DOCKER_HOST=unix:///Users/kevint/.docker/run/docker.sock

# 4. Private Schema
echo "Checking PrivateSchema..."
crossplane render tests/crossplane-composition/xr-private-schema.yml apps/loa-federation/templates/crossplane-init/pgedge/pgedge-private-schema.yml $FUNCTIONS_FILE
echo "OK"

echo "All pipeline compositions rendered successfully!"
