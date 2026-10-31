# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

# terraform/infrastructure/ reads these values here because the deployers
# cannot read this layer's state, which terraform_remote_state needs. Plan on
# any pull request can read this object, so publish only non-secret values.
locals {
  published_outputs = {
    workload_identity_provider = google_iam_workload_identity_pool_provider.github.name
    github_deployer_ro_email   = google_service_account.github_deployer_ro.email
    github_deployer_rw_email   = google_service_account.github_deployer_rw.email
  }
}

resource "google_storage_bucket_object" "published_outputs" {
  bucket       = google_storage_bucket.infrastructure_state.name
  name         = "bootstrap-outputs.json"
  content_type = "application/json"
  content      = jsonencode(local.published_outputs)
}
