#!/bin/bash
# Sets up Workload Identity Federation so GitHub Actions can authenticate
# to GCP without storing a service account key.
#
# Run once:  bash scripts/setup-github-wif.sh <your-github-org-or-username> <your-repo-name>
# Example:   bash scripts/setup-github-wif.sh sneha llm-inference-platform

set -euo pipefail

GITHUB_ORG="${1:?Usage: $0 <github-org-or-username> <repo-name>}"
GITHUB_REPO="${2:?Usage: $0 <github-org-or-username> <repo-name>}"
PROJECT_ID="my-llm-platform"
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
SA_NAME="github-actions-sa"
POOL_NAME="github-pool"
PROVIDER_NAME="github-provider"

echo "==> Creating GitHub Actions service account"
gcloud iam service-accounts create "$SA_NAME" \
  --display-name="GitHub Actions CI/CD" \
  --project="$PROJECT_ID" 2>/dev/null || echo "Already exists"

SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "==> Granting roles to service account"
for ROLE in \
  roles/artifactregistry.writer \
  roles/container.developer \
  roles/iam.serviceAccountUser; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="$ROLE" --quiet
done

echo "==> Creating Workload Identity Pool"
gcloud iam workload-identity-pools create "$POOL_NAME" \
  --location="global" \
  --display-name="GitHub Actions Pool" \
  --project="$PROJECT_ID" 2>/dev/null || echo "Pool already exists"

echo "==> Creating Workload Identity Provider"
gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_NAME" \
  --location="global" \
  --workload-identity-pool="$POOL_NAME" \
  --display-name="GitHub OIDC Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --project="$PROJECT_ID" 2>/dev/null || echo "Provider already exists"

echo "==> Binding service account to GitHub repo"
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_NAME}/attribute.repository/${GITHUB_ORG}/${GITHUB_REPO}" \
  --project="$PROJECT_ID"

WIF_PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_NAME}/providers/${PROVIDER_NAME}"

echo ""
echo "======================================================"
echo " Done! Add these as GitHub Actions secrets:"
echo "======================================================"
echo " WIF_PROVIDER       = ${WIF_PROVIDER}"
echo " WIF_SERVICE_ACCOUNT = ${SA_EMAIL}"
echo "======================================================"
echo ""
echo " In GitHub: Settings → Secrets → Actions → New secret"
