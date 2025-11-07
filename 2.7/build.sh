#!/bin/bash
set -e

vendir sync


# Read version from VERSION file
VERSION=$(yq '.directories[] | select(.path == "upstream") | .contents[] | select(.path == "manifests") | .githubRelease.tag' vendir.lock.yml)
echo "Building flux-boot version $VERSION"

FLUX_YAML="latest/gotk-components.yaml"
FLUX_YAML_VERSION="releases/gotk-components-${VERSION}.yaml"

# Build the bootstrap manifest
echo "Running kustomize build..."
kustomize build . > ${FLUX_YAML}
kustomize build . > ${FLUX_YAML_VERSION}

echo "Generated files:"
echo "  - ${FLUX_YAML}"
echo "  - ${FLUX_YAML_VERSION}"
