#!/bin/bash
set -e

vendir sync


# Read version from VERSION file
VERSION=$(yq '.directories[] | select(.path == "upstream") | .contents[] | select(.path == "manifests") | .githubRelease.tag' vendir.lock.yml)
echo "Building flux-boot version $VERSION"

FLUX_YAML="release/gotk-components.yaml"

# Build the bootstrap manifest
echo "Running kustomize build..."
kustomize build . > ${FLUX_YAML}

echo "Generated files:"
echo "  - ${FLUX_YAML}"
