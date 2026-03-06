#!/usr/bin/env nix-shell
#!nix-shell -i bash -p kubernetes-helm yq-go jq nix-prefetch-docker

set -euo pipefail

# 1. Validate Arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <cluster_name>"
    echo "Example: $0 test"
    exit 1
fi

CLUSTER_NAME="$1"
CLUSTER_DIR="clusters/$CLUSTER_NAME"

# 2. Validate Output Directory
if [ ! -d "$CLUSTER_DIR" ]; then
    echo "[!] Error: Cluster directory '$CLUSTER_DIR' does not exist."
    exit 1
fi

OUTPUT_FILE="$CLUSTER_DIR/charts-lock.json"

echo "========================================"
echo "Updating charts for cluster: $CLUSTER_NAME"
echo "========================================"

# 3. Determine system and build the Nix derivation
SYSTEM=$(nix eval --impure --raw --expr 'builtins.currentSystem')
FLAKE_TARGET=".#packages.${SYSTEM}.chart-index-${CLUSTER_NAME}"

echo "[+] Building Nix derivation: $FLAKE_TARGET"

INPUT_FILE=$(nix build "$FLAKE_TARGET" --no-link --print-out-paths)/chart-index.json

if [ ! -f "$INPUT_FILE" ]; then
    echo "[!] Error: Built derivation output is not a file: $INPUT_FILE"
    exit 1
fi

echo "[+] Successfully built. Reading charts from: $INPUT_FILE"

# Initialize an empty JSON object for our single lockfile
echo "{}" > "$OUTPUT_FILE"
rm -rf /tmp/temp-chart

# 4. Read the JSON array from the Nix store path and iterate over each object
jq -c '.[]' "$INPUT_FILE" | while read -r item; do
  
  name=$(echo "$item" | jq -r '.name')
  is_local=$(echo "$item" | jq -r '.isLocalChart')
  
  # The "chart" field often looks like "repo/chartName" or a local path
  raw_chart=$(echo "$item" | jq -r '.chart')
  chart_base=$(basename "$raw_chart")

  # --- CONDITIONAL BLOCK: FETCH REMOTE OR INIT LOCAL ---
  if [[ "$is_local" != "true" ]]; then
    repo=$(echo "$item" | jq -r '.repo')
    version=$(echo "$item" | jq -r '.version')
    
    echo "[+] Processing remote chart: $chart_base version $version from $repo..."

    # Fetch the repository's index.yaml to a temporary file
    curl -sL "$repo/index.yaml" > /tmp/helm-index.yaml

    # Extract the exact URL and SHA256 digest using yq
    tgz_url=$(yq eval ".entries[\"$chart_base\"][] | select(.version == \"$version\") | .urls[0]" /tmp/helm-index.yaml)
    digest=$(yq eval ".entries[\"$chart_base\"][] | select(.version == \"$version\") | .digest" /tmp/helm-index.yaml)

    # Error handling if the chart/version combination isn't found
    if [[ -z "$tgz_url" || "$tgz_url" == "null" ]]; then
      echo "  [!] Error: Could not find URL for $chart_base $version in $repo"
      continue # Here, continue makes sense: if the remote chart fails, we can't template it anyway
    fi

    # Handle relative URLs
    if [[ "$tgz_url" != http* ]]; then
      clean_repo="${repo%/}"
      tgz_url="$clean_repo/$tgz_url"
    fi

    echo "  -> Found URL: $tgz_url"

    nix_hash=$(nix hash convert --to sri --hash-algo sha256 $digest)
    
    # Append the findings to our lockfile using jq, initializing an empty 'images' object
    jq --arg name "$name" \
       --arg url "$tgz_url" \
       --arg hash "$nix_hash" \
       '.[$name] = { url: $url, hash: $hash, images: {} }' "$OUTPUT_FILE" > /tmp/lock-tmp.json && mv /tmp/lock-tmp.json "$OUTPUT_FILE"
  else
    echo "[-] Local chart detected: $name. Skipping remote index fetch..."
    # Even for local charts, we need to initialize the key in the lockfile so images have a place to live
    jq --arg name "$name" \
       --arg url "file://$raw_chart" \
       '.[$name] = { url: $url, images: {} }' "$OUTPUT_FILE" > /tmp/lock-tmp.json && mv /tmp/lock-tmp.json "$OUTPUT_FILE"
  fi
  # ---------------------------------------------

  # 1. Generate the values.yaml from the NixOS config
  echo "$item" | jq -r '.values' > /tmp/values.yaml

  # 2. Render the template and extract the image tags
  echo "  -> Discovering container images..."
  
  # Helm template requires different arguments depending on if it's local vs remote
  if [[ "$is_local" == "true" ]]; then
    # For local charts, raw_chart should be the directory path
    images=$(helm template "$chart_base" "$raw_chart" -f /tmp/values.yaml | grep "image:" | awk '{print $2}' | tr -d '"' | sort -u || true)
  else
    echo "  -> Pulling chart..."
    helm pull --untar --untardir /tmp/temp-chart $tgz_url
    images=$(helm template "$chart_base" /tmp/temp-chart/$chart_base -f /tmp/values.yaml | grep "image:" | awk '{print $2}' | tr -d '"' | sort -u || true)
  fi

  for img in $images; do
    echo "    - Found image: $img"
    
    img_digest=""
    img_tag=""
    
    # 1. Check for digest (e.g., @sha256:abcdef...)
    if [[ "$img" == *"@"* ]]; then
      img_base="${img%%@*}"
      img_digest="${img##*@}"
      # We MUST keep the 'sha256:' prefix! skopeo requires it.
    else
      img_base="$img"
    fi

    # 2. Check for tag (e.g., :v2.15.0)
    if [[ "$img_base" == *":"* ]]; then
      img_name="${img_base%%:*}"
      img_tag="${img_base##*:}"
    else
      img_name="$img_base"
    fi

    # 3. Build the nix-prefetch-docker command dynamically
    prefetch_cmd=(nix-prefetch-docker --image-name "$img_name" --quiet --json)
    
    if [[ -n "$img_tag" ]]; then
      prefetch_cmd+=(--image-tag "$img_tag")
    elif [[ -z "$img_digest" ]]; then
      # Only assume 'latest' if we have absolutely no tag and no digest
      echo "  [!] No tag or digest given! Assuming latest - but this may cause build failures when bundling!"
      prefetch_cmd+=(--image-tag "latest")
    fi
    
    if [[ -n "$img_digest" ]]; then
      prefetch_cmd+=(--image-digest "$img_digest")
    fi

    # 4. Fetch the Nix-compatible hash as JSON
    echo "      Fetching hash via nix-prefetch-docker..."
    
    hash_info=$("${prefetch_cmd[@]}")
    
    if [[ -z "$hash_info" ]]; then
        echo "  [!] Error: nix-prefetch-docker failed for $img"
        continue
    fi

    # Extract the required fields for Nix
    digest=$(echo "$hash_info" | jq -r '.imageDigest // empty')
    hash=$(echo "$hash_info" | jq -r '.hash // .sha256 // empty')

    # 5. Append the image under the chart's 'images' key in charts-lock.json
    jq --arg chartName "$name" \
       --arg img "$img" \
       --arg name "$img_name" \
       --arg digest "$digest" \
       --arg hash "$hash" \
       '.[$chartName].images[$img] = { imageName: $name, imageDigest: $digest, hash: $hash }' "$OUTPUT_FILE" > /tmp/lock-tmp.json && mv /tmp/lock-tmp.json "$OUTPUT_FILE"
  done

  echo "[+] Finished discovering container images"

done

# Clean up the temporary files
rm -rf /tmp/helm-index.yaml /tmp/values.yaml /tmp/temp-chart

echo "----------------------------------------"
echo "Success! Lockfile written to $OUTPUT_FILE"