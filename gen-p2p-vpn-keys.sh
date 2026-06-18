#!/usr/bin/env bash
# gen-p2p-vpn-keys.sh
# Automates the generation of p2p-vpn keys, CA signatures, and whitelists.

set -euo pipefail

# 1. Locate the p2p-vpn binary
P2P_VPN_BIN=""
if [ -f "$(pwd)/p2p-vpn" ]; then
  P2P_VPN_BIN="$(pwd)/p2p-vpn"
elif [ -f "$(pwd)/../p2p-vpn/p2p-vpn-darwin" ]; then
  P2P_VPN_BIN="$(pwd)/../p2p-vpn/p2p-vpn-darwin"
elif [ -f "$(pwd)/../p2p-vpn/p2p-vpn" ]; then
  P2P_VPN_BIN="$(pwd)/../p2p-vpn/p2p-vpn"
elif command -v p2p-vpn &> /dev/null; then
  P2P_VPN_BIN=$(command -v p2p-vpn)
fi

if [ -z "$P2P_VPN_BIN" ]; then
  # Try to build it dynamically from the neighbor workspace
  if [ -d "../p2p-vpn" ] && command -v go &> /dev/null; then
    echo "Building p2p-vpn binary in neighbor workspace..."
    (cd ../p2p-vpn && go build -o p2p-vpn-darwin)
    P2P_VPN_BIN="$(pwd)/../p2p-vpn/p2p-vpn-darwin"
  else
    echo "Error: p2p-vpn binary not found."
    echo "Please build it in the p2p-vpn workspace first, or make sure 'go' is installed."
    exit 1
  fi
fi

echo "Using p2p-vpn binary: $P2P_VPN_BIN"

# 2. Initialize central CA keys and shared data key
mkdir -p keys/ca

if [ ! -f "keys/ca/ca.key" ] || [ ! -f "keys/ca/ca.pub" ]; then
  echo "🔑 Generating central ML-DSA-87 CA key pair..."
  (cd keys/ca && "$P2P_VPN_BIN" -mode ca-keygen)
fi

if [ ! -f "keys/data.key" ]; then
  echo "🔒 Generating shared 32-byte AES data key..."
  openssl rand -hex 32 > keys/data.key
  chmod 600 keys/data.key
fi

# 3. Determine target clusters
CLUSTERS=()
if [ "$#" -gt 0 ]; then
  CLUSTERS=("$@")
else
  # Auto-discover clusters
  for dir in clusters/*; do
    if [ -d "$dir" ] && [ "$(basename "$dir")" != "_defaults" ] && [ "$(basename "$dir")" != "ca" ]; then
      CLUSTERS+=("$(basename "$dir")")
    fi
  done
fi

if [ ${#CLUSTERS[@]} -eq 0 ]; then
  echo "No clusters found."
  exit 0
fi

echo "Target clusters: ${CLUSTERS[*]}"

# 4. Generate/Load Identity Keys and extract Peer IDs
for cluster in "${CLUSTERS[@]}"; do
  CLUSTERS_KEYS_DIR="clusters/${cluster}/keys"
  mkdir -p "$CLUSTERS_KEYS_DIR"
  
  IDENTITY_FILE="${CLUSTERS_KEYS_DIR}/p2p-vpn-identity.key"
  
  echo "👤 Generating/loading identity key for cluster '$cluster'..."
  # -print-peer-id automatically generates the key if it doesn't exist and prints the Peer ID
  PEER_ID=$("$P2P_VPN_BIN" -identity "$IDENTITY_FILE" -print-peer-id)
  echo "$PEER_ID" > "keys/${cluster}.peer_id"
  echo "   Peer ID: $PEER_ID"
done

# 5. Compile the whitelist containing all cluster Peer IDs
echo "📋 Creating shared whitelist.txt..."
WHITELIST_FILE="keys/whitelist.txt"
rm -f "$WHITELIST_FILE"
for cluster in "${CLUSTERS[@]}"; do
  PEER_ID=$(cat "keys/${cluster}.peer_id")
  echo "# Cluster: $cluster" >> "$WHITELIST_FILE"
  echo "$PEER_ID" >> "$WHITELIST_FILE"
done

# 6. Sign cluster Peer IDs and distribute shared keys
for cluster in "${CLUSTERS[@]}"; do
  CLUSTERS_KEYS_DIR="clusters/${cluster}/keys"
  PEER_ID=$(cat "keys/${cluster}.peer_id")
  
  echo "✍️ Signing Peer ID for cluster '$cluster'..."
  # Signs the peer ID, generating <peer-id>.sig in the current directory
  "$P2P_VPN_BIN" -mode ca-sign -ca-key-priv keys/ca/ca.key -peer "$PEER_ID" >/dev/null
  mv "${PEER_ID}.sig" "${CLUSTERS_KEYS_DIR}/p2p-vpn-node.sig"
  
  echo "🚚 Distributing shared files to cluster '$cluster' keys folder..."
  cp keys/data.key "${CLUSTERS_KEYS_DIR}/p2p-vpn-data.key"
  cp keys/ca/ca.pub "${CLUSTERS_KEYS_DIR}/p2p-vpn-ca.pub"
  cp keys/whitelist.txt "${CLUSTERS_KEYS_DIR}/p2p-vpn-whitelist.txt"
  
  # Ensure correct permissions
  chmod 600 "${CLUSTERS_KEYS_DIR}/p2p-vpn-identity.key"
  chmod 600 "${CLUSTERS_KEYS_DIR}/p2p-vpn-data.key"
  chmod 644 "${CLUSTERS_KEYS_DIR}/p2p-vpn-ca.pub"
  chmod 644 "${CLUSTERS_KEYS_DIR}/p2p-vpn-node.sig"
  chmod 644 "${CLUSTERS_KEYS_DIR}/p2p-vpn-whitelist.txt"
done

# Clean up temp files
rm -f keys/*.peer_id

echo "🎉 Success: Keys generated, signed, whitelisted, and distributed successfully!"
