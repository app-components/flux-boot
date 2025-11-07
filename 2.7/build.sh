#!/bin/bash
set -e

vendir sync

echo ""

FLUX_YAML="release/gotk-components.yaml"

# Build the bootstrap manifest
echo "Running kustomize build..."
kustomize build . > ${FLUX_YAML}

echo "Generated files:"
echo "  - ${FLUX_YAML}"
