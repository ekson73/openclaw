#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-oc-backy}"
REGION="${REGION:-us-central1}"
AR_REPO="${AR_REPO:-openclaw}"
REPO_OWNER="${REPO_OWNER:-mpsb00}"
REPO_NAME="${REPO_NAME:-openclaw}"
SERVICE_ACCOUNT_ID="${SERVICE_ACCOUNT_ID:-github-cloudbuild}"
WIF_POOL_ID="${WIF_POOL_ID:-github-pool}"
WIF_PROVIDER_ID="${WIF_PROVIDER_ID:-github-provider}"
GH_REPO="${REPO_OWNER}/${REPO_NAME}"

echo "==> Using project: ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}" >/dev/null

echo "==> Enabling required APIs"
gcloud services enable \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  compute.googleapis.com \
  --project "${PROJECT_ID}"

echo "==> Creating Artifact Registry repo if missing"
if ! gcloud artifacts repositories describe "${AR_REPO}" \
  --location "${REGION}" \
  --project "${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud artifacts repositories create "${AR_REPO}" \
    --repository-format=docker \
    --location="${REGION}" \
    --description="OpenClaw images" \
    --project "${PROJECT_ID}"
fi

echo "==> Ensuring Cloud Build service account can push to Artifact Registry"
PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
CB_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/artifactregistry.writer" \
  --quiet >/dev/null

echo "==> Creating GitHub Actions deploy service account if missing"
if ! gcloud iam service-accounts describe \
  "${SERVICE_ACCOUNT_ID}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project "${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud iam service-accounts create "${SERVICE_ACCOUNT_ID}" \
    --display-name="GitHub Actions Cloud Build submitter" \
    --project "${PROJECT_ID}"
fi

GHA_SA="${SERVICE_ACCOUNT_ID}@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${GHA_SA}" \
  --role="roles/cloudbuild.builds.editor" \
  --quiet >/dev/null
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${GHA_SA}" \
  --role="roles/serviceusage.serviceUsageConsumer" \
  --quiet >/dev/null

echo "==> Creating Workload Identity pool/provider if missing"
if ! gcloud iam workload-identity-pools describe "${WIF_POOL_ID}" \
  --location="global" \
  --project "${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud iam workload-identity-pools create "${WIF_POOL_ID}" \
    --location="global" \
    --display-name="GitHub Actions Pool" \
    --project "${PROJECT_ID}"
fi

if ! gcloud iam workload-identity-pools providers describe "${WIF_PROVIDER_ID}" \
  --location="global" \
  --workload-identity-pool="${WIF_POOL_ID}" \
  --project "${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud iam workload-identity-pools providers create-oidc "${WIF_PROVIDER_ID}" \
    --location="global" \
    --workload-identity-pool="${WIF_POOL_ID}" \
    --display-name="GitHub OIDC Provider" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.ref=assertion.ref" \
    --attribute-condition="assertion.repository=='${GH_REPO}'" \
    --project "${PROJECT_ID}"
fi

PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
WIF_PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL_ID}/providers/${WIF_PROVIDER_ID}"

echo "==> Granting Workload Identity user binding"
gcloud iam service-accounts add-iam-policy-binding "${GHA_SA}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL_ID}/attribute.repository/${GH_REPO}" \
  --project "${PROJECT_ID}" \
  --quiet >/dev/null

echo "==> Writing GitHub repo variables (${GH_REPO})"
gh variable set GCP_PROJECT_ID --repo "${GH_REPO}" --body "${PROJECT_ID}"
gh variable set GCP_REGION --repo "${GH_REPO}" --body "${REGION}"
gh variable set GCP_AR_REPO --repo "${GH_REPO}" --body "${AR_REPO}"
gh variable set GCP_IMAGE_NAME --repo "${GH_REPO}" --body "openclaw-gateway"
gh variable set GCP_WIF_PROVIDER --repo "${GH_REPO}" --body "${WIF_PROVIDER}"
gh variable set GCP_WIF_SERVICE_ACCOUNT --repo "${GH_REPO}" --body "${GHA_SA}"

echo "==> Setup complete"
echo "Workload Identity Provider: ${WIF_PROVIDER}"
echo "Service Account: ${GHA_SA}"
