#!/usr/bin/env bash
set -euo pipefail

current="$(sed -n 's/^version:[[:space:]]*//p' Chart.yaml | head -n1 | tr -d '"')"
IFS='.' read -r major minor patch <<<"${current}"
patch=$((patch + 1))
next="${major}.${minor}.${patch}"

sed -i.bak "s/^version:[[:space:]]*.*/version: ${next}/" Chart.yaml
rm -f Chart.yaml.bak

sed -i.bak "s/^[[:space:]]*targetRevision:[[:space:]]*.*/    targetRevision: ${next}/" examples/argocd/application.yaml
rm -f examples/argocd/application.yaml.bak

sed -i.bak "s/^[[:space:]]*version:[[:space:]]*.*/      version: ${next}/" examples/flux/helmrelease.yaml
rm -f examples/flux/helmrelease.yaml.bak
