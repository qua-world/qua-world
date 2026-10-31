# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

resource "google_project_service" "secretmanager" {
  project = google_project.infrastructure.project_id
  service = "secretmanager.googleapis.com"

  disable_on_destroy = false

  depends_on = [google_project_service.serviceusage]
}

# Empty shells. scripts/bootstrap.sh adds the versions once this has applied,
# because a version Terraform created would put the private key in this
# layer's state.
resource "google_secret_manager_secret" "github_app" {
  for_each = local.github_app_secrets

  project   = google_project.infrastructure.project_id
  secret_id = each.value

  replication {
    user_managed {
      replicas {
        location = local.region
      }
    }
  }

  depends_on = [google_project_service.secretmanager]
}
