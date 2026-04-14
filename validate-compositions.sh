#!/bin/bash
set -e

# Ensure functions.yaml exists in the current directory or point to a shared one
FUNCTIONS_FILE="apps/loa-core/templates/crossplane/pkgs/functions.yml"
export DOCKER_HOST=unix:///Users/kevint/.docker/run/docker.sock

echo "Checking PrivateSchema..."
crossplane render tests/crossplane-composition/xr-private-schema.yml apps/loa-federation/templates/crossplane-init/pgedge/pgedge-private-schema.yml $FUNCTIONS_FILE
echo "OK"

echo "Checking SyncFolder..."
crossplane render tests/crossplane-composition/xr-sync-folder.yml apps/loa-core/templates/crossplane/compositions/seaweedfs-sync-folder.yml $FUNCTIONS_FILE
echo "OK"

echo "Checking PeerBucket..."
crossplane render tests/crossplane-composition/xr-peer-bucket.yml apps/loa-core/templates/crossplane/compositions/seaweedfs-peer-bucket.yml $FUNCTIONS_FILE
echo "OK"

echo "All pipeline compositions rendered successfully!"
