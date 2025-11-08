#!/bin/bash
set -e

vendir sync

# Read version from VERSION file
VERSION=$(yq '.directories[] | select(.path == "upstream") | .contents[] | select(.path == "manifests") | .githubRelease.tag' vendir.lock.yml)
echo "Building flux-boot version $VERSION"

# --- 1. Get the Git Repository Root ---
# Define the variable REPO_ROOT (Absolute path to the repository root)
REPO_ROOT=$(git rev-parse --show-toplevel)

# --- 2. Get the Script's Directory Information ---
# Get the ABSOLUTE PATH to the directory containing this script (e.g., /path/to/repo/tools)
SCRIPT_ABSOLUTE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Get only the DIRECTORY NAME of where the script is (e.g., tools)
SCRIPT_DIR_NAME=$(basename "$SCRIPT_ABSOLUTE_PATH")

RELEASE_DIR="${REPO_ROOT}/releases/$SCRIPT_DIR_NAME"

FLUX_YAML="${RELEASE_DIR}/latest/gotk-components.yaml"
FLUX_YAML_VERSION="${RELEASE_DIR}/versions/gotk-components-${VERSION}.yaml"

# Build the bootstrap manifest
echo "Running kustomize build..."
kustomize build . > ${FLUX_YAML}
kustomize build . > ${FLUX_YAML_VERSION}

echo "Generated files:"
echo "  - ${FLUX_YAML}"
echo "  - ${FLUX_YAML_VERSION}"
