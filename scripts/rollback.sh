#!/bin/bash
# ============================================================
# rollback.sh — Image-based rollback to previous tagged version
# Usage:
#   Automatic: called by CI/CD on smoke test failure
#   Manual:    bash scripts/rollback.sh [commit-hash]
# ============================================================

set -e

DOCKER_HUB_USERNAME="${DOCKER_HUB_USERNAME:-your_dockerhub_username}"
IMAGE_FRONTEND="${DOCKER_HUB_USERNAME}/employee-frontend"
IMAGE_BACKEND="${DOCKER_HUB_USERNAME}/employee-backend"

echo "============================================"
echo "  Employee Dashboard — Rollback Script"
echo "============================================"

# If a specific tag is passed as argument, use it
if [ -n "$1" ]; then
  ROLLBACK_TAG="$1"
  echo "Rolling back to specified tag: $ROLLBACK_TAG"
else
  # Auto-detect previous tag from Docker Hub (second most recent = previous)
  echo "No tag specified. Fetching previous image tag from Docker Hub..."

  TAGS_JSON=$(curl -s "https://hub.docker.com/v2/repositories/${IMAGE_FRONTEND}/tags?page_size=5")
  ROLLBACK_TAG=$(echo "$TAGS_JSON" | python3 -c "
import sys, json
tags = json.load(sys.stdin)['results']
# Filter out 'latest', pick the second most recent commit-hash tag
non_latest = [t['name'] for t in tags if t['name'] != 'latest']
print(non_latest[1] if len(non_latest) > 1 else non_latest[0])
")

  echo "Detected previous tag: $ROLLBACK_TAG"
fi

echo ""
echo "Pulling previous images..."
docker pull "${IMAGE_FRONTEND}:${ROLLBACK_TAG}"
docker pull "${IMAGE_BACKEND}:${ROLLBACK_TAG}"

echo ""
echo "Re-tagging as latest..."
docker tag "${IMAGE_FRONTEND}:${ROLLBACK_TAG}" "${IMAGE_FRONTEND}:latest"
docker tag "${IMAGE_BACKEND}:${ROLLBACK_TAG}" "${IMAGE_BACKEND}:latest"

echo ""
echo "Redeploying with rolled-back images..."
docker compose down
docker compose up -d

echo ""
echo "Rollback to tag '${ROLLBACK_TAG}' completed successfully."
echo "============================================"
