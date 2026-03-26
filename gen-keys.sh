#!/bin/bash

# 1. Validate that a cluster name argument was provided
if [ -z "$1" ]; then
  echo "Error: Cluster name argument is missing."
  echo "Usage: $0 <cluster_name>"
  exit 1
fi

CLUSTER_NAME="$1"
TARGET_DIR="clusters/${CLUSTER_NAME}/keys"

# 2. Create the directory structure if it doesn't already exist
mkdir -p "${TARGET_DIR}"

# 3. Generate secure random tokens (using openssl to generate 32-byte hex strings)
TOKEN_CONTENT=$(openssl rand -hex 32)
AGENT_TOKEN_CONTENT=$(openssl rand -hex 32)

# 4. Write the secrets to their respective files
echo "${TOKEN_CONTENT}" > "${TARGET_DIR}/token.key"
echo "${AGENT_TOKEN_CONTENT}" > "${TARGET_DIR}/agent-token.key"

# 5. Restrict file permissions so only the owner can read/write them
chmod 600 "${TARGET_DIR}/token.key"
chmod 600 "${TARGET_DIR}/agent-token.key"

echo "Success: Secrets created securely in ${TARGET_DIR}/"