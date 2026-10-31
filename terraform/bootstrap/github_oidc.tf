# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

resource "google_project_service" "sts" {
  project = google_project.infrastructure.project_id
  service = "sts.googleapis.com"

  disable_on_destroy = false

  depends_on = [google_project_service.serviceusage]
}

resource "google_project_service" "iam_credentials" {
  project = google_project.infrastructure.project_id
  service = "iamcredentials.googleapis.com"

  disable_on_destroy = false

  depends_on = [google_project_service.serviceusage]
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = google_project.infrastructure.project_id
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  description               = "Workload Identity Pool for GitHub Actions"
  disabled                  = false

  depends_on = [google_project_service.sts]
}

# The condition admits this repository alone, so a token minted for any other
# qua-world repository cannot reach this state.
resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = google_project.infrastructure.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub"
  description                        = "OIDC provider for GitHub Actions"
  disabled                           = false

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.environment"      = "assertion.environment"
    "attribute.ref"              = "assertion.ref"
  }

  attribute_condition = "assertion.repository == '${local.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

locals {
  wif_pool = "projects/${google_project.infrastructure.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}"

  # Plan runs on pull requests, so no branch pins this one and
  # attribute_condition is its only bound.
  wif_principal_any_ref = "principalSet://iam.googleapis.com/${local.wif_pool}/attribute.repository/${local.github_repository}"

  # Apply only ever runs against the default branch.
  wif_principal_develop = "principalSet://iam.googleapis.com/${local.wif_pool}/attribute.ref/refs/heads/develop"
}
