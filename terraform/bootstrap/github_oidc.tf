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
    "attribute.deployer"         = "assertion.job_workflow_ref in ${jsonencode(local.deployer_rw_workflow_refs)} ? '${local.deployer_rw}' : 'none'"
  }

  attribute_condition = "assertion.repository == '${local.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Any job in this repository can request an OIDC token, so the RW deployer
# binds on job_workflow_ref, which names the repository, workflow file, and ref.
#
# The bindings must match the provider's mapping and condition. A mismatch
# fails the exchange silently.
locals {
  wif_pool_prefix = "principalSet://iam.googleapis.com/projects/${google_project.infrastructure.number}/locations/global/workloadIdentityPools"

  deployer_rw = "rw"

  deployer_rw_workflow_refs = [
    "${local.github_repository}/.github/workflows/deployer-access.yml@refs/heads/develop",
  ]

  wif_principal             = "${local.wif_pool_prefix}/github/attribute.repository/${local.github_repository}"
  wif_principal_deployer_rw = "${local.wif_pool_prefix}/github/attribute.deployer/${local.deployer_rw}"
}
