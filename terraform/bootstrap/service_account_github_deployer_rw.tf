# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

resource "google_service_account" "github_deployer_rw" {
  project      = google_project.infrastructure.project_id
  account_id   = "github-deployer-rw"
  display_name = "GitHub Applier"
  description  = "GitHub Actions service account with write access for terraform apply"

  depends_on = [google_project_service.iam]
}

# Extend only when a resource in terraform/infrastructure/ fails to apply without it.
resource "google_project_iam_custom_role" "github_deployer_rw_applier" {
  project     = google_project.infrastructure.project_id
  role_id     = "githubDeployerApplier"
  title       = "GitHub Deployer Applier"
  description = "Least-privilege role for terraform apply in CI"

  permissions = [
    "resourcemanager.projects.get",
    "serviceusage.services.enable",
    "serviceusage.services.get",
    "serviceusage.services.list",
    "serviceusage.services.use",
  ]

  depends_on = [google_project_service.serviceusage]
}

resource "google_project_iam_member" "github_deployer_rw_applier" {
  project = google_project.infrastructure.project_id
  role    = google_project_iam_custom_role.github_deployer_rw_applier.name
  member  = "serviceAccount:${google_service_account.github_deployer_rw.email}"
}
