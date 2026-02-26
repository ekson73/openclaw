#!/usr/bin/env bash
set -euo pipefail

INSTANCE="${INSTANCE:-openclaw-gateway}"
ZONE="${ZONE:-us-central1-a}"
PROJECT_ID="${PROJECT_ID:-oc-backy}"
IMAGE_TAG="${IMAGE_TAG:-main}"
REGION="${REGION:-us-central1}"
AR_REPO="${AR_REPO:-openclaw}"
IMAGE_NAME="${IMAGE_NAME:-openclaw-gateway}"

REMOTE_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "==> Switching ${INSTANCE} to image: ${REMOTE_IMAGE}"
echo "==> Project: ${PROJECT_ID}, Zone: ${ZONE}"

gcloud compute ssh "${INSTANCE}" \
  --project "${PROJECT_ID}" \
  --zone "${ZONE}" \
  --command "
set -euo pipefail
cd ~/openclaw
ts=\$(date +%Y%m%d-%H%M%S)
cp .env .env.backup.\${ts}
cp docker-compose.yml docker-compose.yml.backup.\${ts}

if grep -q '^OPENCLAW_IMAGE=' .env; then
  sed -i 's|^OPENCLAW_IMAGE=.*|OPENCLAW_IMAGE=${REMOTE_IMAGE}|' .env
else
  printf '\nOPENCLAW_IMAGE=${REMOTE_IMAGE}\n' >> .env
fi

# Runtime-only pull model; avoid local builds on the VM.
if grep -q '^[[:space:]]*build:' docker-compose.yml; then
  sed -i '/^[[:space:]]*build:[[:space:]]*\\.?[[:space:]]*$/d' docker-compose.yml
fi

docker compose pull openclaw-gateway openclaw-cli || docker compose pull
docker compose up -d openclaw-gateway
docker compose ps
docker compose logs --tail=50 openclaw-gateway

echo \"Rollback files:\"
echo \"  .env.backup.\${ts}\"
echo \"  docker-compose.yml.backup.\${ts}\"
"
