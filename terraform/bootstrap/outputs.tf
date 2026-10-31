# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

output "project_id" {
  value       = google_project.infrastructure.project_id
  description = "GCP project ID for qua-world's Terraform"
}

output "project_number" {
  value       = google_project.infrastructure.number
  description = "GCP project number, needed to build principalSet identifiers"
}

output "state_bucket" {
  value       = data.google_storage_bucket.bootstrap_state.name
  description = "GCS bucket holding this layer's Terraform state"
}

output "workload_identity_provider" {
  value       = local.published_outputs.workload_identity_provider
  description = "GitHub WIF provider, for google-github-actions/auth's workload_identity_provider input"
}

output "github_deployer_ro_email" {
  value       = local.published_outputs.github_deployer_ro_email
  description = "Email of the read-only deployer service account (terraform plan)"
}

output "github_deployer_rw_email" {
  value       = local.published_outputs.github_deployer_rw_email
  description = "Email of the read-write deployer service account (terraform apply)"
}
