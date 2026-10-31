# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

resource "google_service_account" "github_deployer_ro" {
  project      = google_project.infrastructure.project_id
  account_id   = "github-deployer-ro"
  display_name = "GitHub Planner"
  description  = "GitHub Actions service account with read-only access for plan runs"

  depends_on = [google_project_service.iam]
}

# Extend only when a resource in terraform/infrastructure/ fails to refresh without it.
resource "google_project_iam_custom_role" "github_deployer_ro_planner" {
  project     = google_project.infrastructure.project_id
  role_id     = "githubDeployerPlanner"
  title       = "GitHub Deployer Planner"
  description = "Least-privilege read role for terraform plan in CI"

  permissions = [
    "resourcemanager.projects.get",
    "serviceusage.services.get",
    "serviceusage.services.list",
  ]

  depends_on = [google_project_service.serviceusage]
}

resource "google_project_iam_member" "github_deployer_ro_planner" {
  project = google_project.infrastructure.project_id
  role    = google_project_iam_custom_role.github_deployer_ro_planner.name
  member  = "serviceAccount:${google_service_account.github_deployer_ro.email}"
}
