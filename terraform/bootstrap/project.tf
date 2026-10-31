# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

# scripts/bootstrap.sh creates the project, because the state bucket lives
# inside it. Adopting it here keeps billing and labels in code. The import
# block is idempotent once the project is in state, so it stays.
import {
  to = google_project.infrastructure
  id = local.project_id
}

resource "google_project" "infrastructure" {
  name                = "Qua World Infrastructure"
  project_id          = local.project_id
  auto_create_network = false
  billing_account     = var.billing_account_id

  labels = {
    environment = "production"
    created_by  = "bootstrap"
    managed_by  = "terraform"
  }

  lifecycle {
    # Only consulted at creation, and the script does the creating.
    ignore_changes = [auto_create_network]

    prevent_destroy = true
  }
}

resource "google_project_service" "iam" {
  project = google_project.infrastructure.project_id
  service = "iam.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "cloudresourcemanager" {
  project = google_project.infrastructure.project_id
  service = "cloudresourcemanager.googleapis.com"

  disable_on_destroy = false

  depends_on = [google_project_service.iam]
}

resource "google_project_service" "serviceusage" {
  project = google_project.infrastructure.project_id
  service = "serviceusage.googleapis.com"

  disable_on_destroy = false

  depends_on = [google_project_service.iam]
}

# Data Access logs are opt-in per service. Without them, a compromised plan
# job could read every object in the state bucket and leave no trace beyond
# the STS impersonation row in Admin Activity.
resource "google_project_iam_audit_config" "storage" {
  project = google_project.infrastructure.project_id
  service = "storage.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}
