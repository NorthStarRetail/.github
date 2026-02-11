#!/bin/bash
# Build and push all NorthStar service images to Docker registry
# Usage: ./scripts/build-and-push-images.sh [registry] [tag]
# Example: ./scripts/build-and-push-images.sh docker.io/yourusername v1.0.0
# Example: ./scripts/build-and-push-images.sh your-registry.com/northstar latest

set -e

REGISTRY=${1:-"docker.io/yourusername"}
TAG=${2:-"latest"}
SERVICES=(
  "northstar-discovery-service"
  "northstar-gateway-service"
  "northstar-auth-service"
  "northstar-book-service"
  "northstar-store-service"
  "northstar-order-service"
  "northstar-inventory-service"
  "northstar-notification-service"
)

echo "Building and pushing images to ${REGISTRY} with tag ${TAG}"
echo "=========================================="

for service in "${SERVICES[@]}"; do
  echo ""
  echo "Building ${service}..."
  cd "${service}"
  
  # Build image
  docker build -t "${service}:${TAG}" .
  
  # Tag for registry
  docker tag "${service}:${TAG}" "${REGISTRY}/${service}:${TAG}"
  
  # Push to registry
  echo "Pushing ${REGISTRY}/${service}:${TAG}..."
  docker push "${REGISTRY}/${service}:${TAG}"
  
  cd ..
  echo "✓ ${service} completed"
done

echo ""
echo "=========================================="
echo "All images built and pushed successfully!"
echo ""
echo "To use these images, run:"
echo "  DOCKER_REGISTRY=${REGISTRY} IMAGE_TAG=${TAG} docker compose -f docker-compose.registry.yml up -d"
