#!/bin/bash
# Build script for CNPG PostgreSQL with Nhost Extensions

set -e

# Configuration
REGISTRY="${REGISTRY:-harbor.hahomelabs.com}"
IMAGE_NAME="${IMAGE_NAME:-mycritters/cnpg-postgres}"
PG_VERSION="${PG_VERSION:-17}"
TAG="${TAG:-${PG_VERSION}-$(date +%Y%m%d)}"

echo "Building CNPG PostgreSQL ${PG_VERSION} with Nhost Extensions"
echo "Registry: ${REGISTRY}"
echo "Image: ${IMAGE_NAME}:${TAG}"
echo ""

# Build the image
docker build \
  --build-arg PG_MAJOR=${PG_VERSION} \
  -t ${IMAGE_NAME}:${TAG} \
  -t ${IMAGE_NAME}:${PG_VERSION} \
  -t ${IMAGE_NAME}:latest \
  .

echo ""
echo "Build complete!"
echo ""
echo "Local tags:"
echo "  - ${IMAGE_NAME}:${TAG}"
echo "  - ${IMAGE_NAME}:${PG_VERSION}"
echo "  - ${IMAGE_NAME}:latest"
echo ""

# Optionally push to registry
if [ "${PUSH}" = "true" ]; then
  echo "Pushing to registry..."

  docker tag ${IMAGE_NAME}:${TAG} ${REGISTRY}/${IMAGE_NAME}:${TAG}
  docker tag ${IMAGE_NAME}:${PG_VERSION} ${REGISTRY}/${IMAGE_NAME}:${PG_VERSION}
  docker tag ${IMAGE_NAME}:latest ${REGISTRY}/${IMAGE_NAME}:latest

  docker push ${REGISTRY}/${IMAGE_NAME}:${TAG}
  docker push ${REGISTRY}/${IMAGE_NAME}:${PG_VERSION}
  docker push ${REGISTRY}/${IMAGE_NAME}:latest

  echo ""
  echo "Pushed to registry:"
  echo "  - ${REGISTRY}/${IMAGE_NAME}:${TAG}"
  echo "  - ${REGISTRY}/${IMAGE_NAME}:${PG_VERSION}"
  echo "  - ${REGISTRY}/${IMAGE_NAME}:latest"
fi

echo ""
echo "To push to registry, run:"
echo "  PUSH=true ./build.sh"
echo ""
echo "To build a different PostgreSQL version:"
echo "  PG_VERSION=16 ./build.sh"
