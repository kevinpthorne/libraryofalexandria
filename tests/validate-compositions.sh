#!/bin/bash
set -e

# Ensure functions.yaml exists in the current directory or point to a shared one
FUNCTIONS_FILE="apps/loa-core/templates/crossplane/pkgs/functions.yml"
DOCKER_HOST=unix:///Users/kevint/.docker/run/docker.sock

# 1. Secret Store
echo "Checking SecretStore..."
crossplane render tests/fixtures/crossplane/xr-secret-store.yml apps/loa-core/templates/crossplane/compositions/secret-store.yml $FUNCTIONS_FILE
echo "OK"

# 2. Synced Secret
echo "Checking SyncedSecret..."
crossplane render tests/fixtures/crossplane/xr-synced-secret.yml apps/loa-core/templates/crossplane/compositions/synced-secret.yml $FUNCTIONS_FILE
echo "OK"

# 3. Synced Cert
echo "Checking SyncedCert..."
crossplane render tests/fixtures/crossplane/xr-synced-cert.yml apps/loa-core/templates/crossplane/compositions/synced-cert.yml $FUNCTIONS_FILE
echo "OK"

# 4. Private Schema
echo "Checking PrivateSchema..."
crossplane render tests/fixtures/crossplane/xr-private-schema.yml apps/loa-federation/templates/crossplane-init/pgedge/pgedge-private-schema.yml $FUNCTIONS_FILE
echo "OK"

echo "All pipeline compositions rendered successfully!"
