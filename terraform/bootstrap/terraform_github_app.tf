# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

resource "google_project_service" "secretmanager" {
  project = google_project.infrastructure.project_id
  service = "secretmanager.googleapis.com"

  disable_on_destroy = false

  depends_on = [google_project_service.serviceusage]
}

# Plan runs whatever workflow a pull request supplies, so each deployer reads
# only its own App's credentials: plan the read-only App, apply the read-write.
locals {
  terraform_github_app_readers = {
    for pair in setproduct(["terraform-github-app-id", "terraform-github-app-private-key"], keys(local.deployers)) :
    "${pair[0]}-${pair[1]}" => pair[1]
  }
}

# Empty shells. scripts/bootstrap.sh adds the versions after this layer
# applies, so the private keys never reach this layer's state.
resource "google_secret_manager_secret" "terraform_github_app" {
  for_each = local.terraform_github_app_readers

  project   = google_project.infrastructure.project_id
  secret_id = each.key

  replication {
    user_managed {
      replicas {
        location = local.region
      }
    }
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_iam_member" "terraform_github_app" {
  for_each = local.terraform_github_app_readers

  project   = google_secret_manager_secret.terraform_github_app[each.key].project
  secret_id = google_secret_manager_secret.terraform_github_app[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.deployers[each.value]}"
}
