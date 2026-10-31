#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

# First-time setup. Creates the GCP project and GCS bucket holding Terraform
# state — which terraform/bootstrap/ cannot create for itself, because its own
# state lives in them — then applies that layer and hands CI its federation
# identifiers. Re-running is a no-op.

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-qua-world-infrastructure}"
PROJECT_NAME="${PROJECT_NAME:-Qua World Infrastructure}"
BUCKET_NAME="${BUCKET_NAME:-qua-world-tfstate}"
LOCATION="${LOCATION:-europe-west2}"
REPOSITORY="${REPOSITORY:-qua-world/qua-world}"
LAYER="terraform/bootstrap"

die() {
  echo "error: $*" >&2
  exit 1
}

check_preconditions() {
  command -v gcloud >/dev/null || die "gcloud not found in PATH"
  command -v terraform >/dev/null || die "terraform not found in PATH"
  command -v gh >/dev/null || die "gh not found in PATH"
}

# Both the billing link below and `terraform apply` read this, and each would
# otherwise ask for it separately.
resolve_billing_account() {
  [[ -z "${TF_VAR_billing_account_id:-}" ]] || return

  [[ -t 0 ]] || die "TF_VAR_billing_account_id is unset and stdin is not a terminal"

  # A closed account cannot be linked, so offering one is a dead end. ID first
  # in each row: display names contain spaces, IDs do not.
  local -a accounts=()
  local account
  while IFS= read -r account; do
    accounts+=("${account}")
  done < <(gcloud billing accounts list --filter=open=true \
    --format='value[separator=" "](name.basename(), displayName)')

  if ((${#accounts[@]} == 0)); then
    die "no open billing account available to ${USER}"
  elif ((${#accounts[@]} == 1)); then
    TF_VAR_billing_account_id="${accounts[0]%% *}"
  else
    local choice
    PS3="Billing account: "
    select choice in "${accounts[@]}"; do
      [[ -n "${choice}" ]] || continue
      TF_VAR_billing_account_id="${choice%% *}"
      break
    done
  fi

  export TF_VAR_billing_account_id
  echo "Using billing account ${TF_VAR_billing_account_id}"
}

ensure_project() {
  if gcloud projects describe "${PROJECT_ID}" >/dev/null 2>&1; then
    echo "Project ${PROJECT_ID} already exists."
    return
  fi

  echo "Creating project ${PROJECT_ID}"
  gcloud projects create "${PROJECT_ID}" --name "${PROJECT_NAME}"
}

# A bucket cannot be created in a project with no open billing account, and
# terraform/bootstrap/ cannot link one before its state has somewhere to live.
ensure_billing_link() {
  local linked
  linked="$(gcloud billing projects describe "${PROJECT_ID}" \
    --format='value(billingAccountName)' 2>/dev/null || true)"

  if [[ "${linked}" == "billingAccounts/${TF_VAR_billing_account_id}" ]]; then
    echo "Billing account ${TF_VAR_billing_account_id} already linked."
    return
  fi

  echo "Linking billing account ${TF_VAR_billing_account_id}"
  gcloud billing projects link "${PROJECT_ID}" \
    --billing-account "${TF_VAR_billing_account_id}"
}

ensure_bootstrap_state_bucket() {
  if gcloud storage buckets describe "gs://${BUCKET_NAME}" \
    --project "${PROJECT_ID}" >/dev/null 2>&1; then
    echo "Bucket gs://${BUCKET_NAME} already exists."
  else
    echo "Creating bucket gs://${BUCKET_NAME}"
    gcloud storage buckets create "gs://${BUCKET_NAME}" \
      --project "${PROJECT_ID}" \
      --location "${LOCATION}" \
      --public-access-prevention \
      --uniform-bucket-level-access
  fi

  # Runs unconditionally so an existing bucket converges. Versioning is what
  # makes a corrupted state file recoverable.
  gcloud storage buckets update "gs://${BUCKET_NAME}" \
    --project "${PROJECT_ID}" \
    --versioning
}

apply_bootstrap_layer() {
  terraform -chdir="${LAYER}" init
  terraform -chdir="${LAYER}" apply
}

secret_is_populated() {
  local state
  state="$(gcloud secrets versions describe latest --secret "$1" \
    --project "${PROJECT_ID}" --format='value(state)' 2>/dev/null || true)"

  [[ "${state}" == "ENABLED" ]]
}

add_secret_version() {
  gcloud secrets versions add "$1" --project "${PROJECT_ID}" --data-file=-
}

ensure_github_app_identifier() {
  local secret="$1" label="$2" value="$3"

  if secret_is_populated "${secret}"; then
    echo "${secret} already set."
    return
  fi

  if [[ -z "${value}" && -t 0 ]]; then
    read -rp "${label} (Enter to skip): " value
  fi

  if [[ -z "${value}" ]]; then
    echo "Leaving ${secret} empty; see docs/how-to/create-github-app.md"
    return
  fi

  [[ "${value}" =~ ^[0-9]+$ ]] || die "${label} must be digits, got '${value}'"

  printf '%s' "${value}" | add_secret_version "${secret}"
}

ensure_github_app_private_key() {
  local secret="$1"
  local path="${GITHUB_APP_PRIVATE_KEY_PATH:-}"

  if secret_is_populated "${secret}"; then
    echo "${secret} already set."
    return
  fi

  if [[ -z "${path}" && -t 0 ]]; then
    read -rp "Path to the App's private key .pem (Enter to skip): " path
  fi

  if [[ -z "${path}" ]]; then
    echo "Leaving ${secret} empty; see docs/how-to/create-github-app.md"
    return
  fi

  # read hands back the tilde the shell would have expanded.
  path="${path/#\~/${HOME}}"

  [[ -r "${path}" ]] || die "cannot read ${path}"

  # Signing with the wrong bytes surfaces inside the provider as an opaque
  # JWT error, a long way from the paste that caused it.
  grep -q -- '-----BEGIN .*PRIVATE KEY-----' "${path}" ||
    die "${path} is not a PEM private key"

  add_secret_version "${secret}" <"${path}"
  echo "Shred ${path} once the infrastructure layer authenticates."
}

# The values only exist once the App is registered, which is a browser action,
# so a run before that legitimately leaves the secrets empty.
ensure_github_app_secrets() {
  ensure_github_app_identifier github-app-id \
    "App ID" "${GITHUB_APP_ID:-}"
  ensure_github_app_identifier github-app-installation-id \
    "Installation ID" "${GITHUB_APP_INSTALLATION_ID:-}"
  ensure_github_app_private_key github-app-private-key
}

# Workflows authenticate to GCP with these. None is secret, and setting one
# that already holds the value is a no-op.
set_actions_variables() {
  local -A outputs=(
    [GCP_WORKLOAD_IDENTITY_PROVIDER]=workload_identity_provider
    [GCP_DEPLOYER_RO_EMAIL]=github_deployer_ro_email
    [GCP_DEPLOYER_RW_EMAIL]=github_deployer_rw_email
  )

  local variable value
  for variable in "${!outputs[@]}"; do
    value="$(terraform -chdir="${LAYER}" output -raw "${outputs[${variable}]}")"
    gh variable set "${variable}" --repo "${REPOSITORY}" --body "${value}"
  done
}

main() {
  cd "$(git rev-parse --show-toplevel)" || die "not inside a git work tree"

  check_preconditions
  resolve_billing_account
  ensure_project
  ensure_billing_link
  ensure_bootstrap_state_bucket
  apply_bootstrap_layer
  set_actions_variables
  ensure_github_app_secrets
}

main "$@"
