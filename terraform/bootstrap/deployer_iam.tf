# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

locals {
  deployers = {
    ro = {
      service_account_id        = google_service_account.github_deployer_ro.name
      email                     = google_service_account.github_deployer_ro.email
      infrastructure_state_role = "roles/storage.objectViewer"
      principal                 = local.wif_principal_any_ref
    }
    rw = {
      service_account_id        = google_service_account.github_deployer_rw.name
      email                     = google_service_account.github_deployer_rw.email
      infrastructure_state_role = "roles/storage.objectAdmin"
      principal                 = local.wif_principal_develop
    }
  }

  # The GitHub App credentials terraform/infrastructure/ authenticates with.
  deployer_secret_grants = {
    for pair in setproduct(keys(local.deployers), local.github_app_secrets) :
    "${pair[0]}-${pair[1]}" => {
      email  = local.deployers[pair[0]].email
      secret = pair[1]
    }
  }
}

# Plan authenticates the providers too, so read access is not the applier's
# alone.
resource "google_secret_manager_secret_iam_member" "deployer_secrets" {
  for_each = local.deployer_secret_grants

  project   = google_project.infrastructure.project_id
  secret_id = google_secret_manager_secret.github_app[each.value.secret].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value.email}"
}

resource "google_storage_bucket_iam_member" "deployer_state_objects" {
  for_each = local.deployers

  bucket = google_storage_bucket.infrastructure_state.name
  role   = each.value.infrastructure_state_role
  member = "serviceAccount:${each.value.email}"
}

resource "google_storage_bucket_iam_member" "deployer_state_bucket_reader" {
  for_each = local.deployers

  bucket = google_storage_bucket.infrastructure_state.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${each.value.email}"
}

# Token exchange takes two steps — the pool admits the GitHub token as the
# account, then mints an access token for it — and each needs its own role.
resource "google_service_account_iam_member" "deployer_workload_identity_user" {
  for_each = local.deployers

  service_account_id = each.value.service_account_id
  role               = "roles/iam.workloadIdentityUser"
  member             = each.value.principal

  depends_on = [google_iam_workload_identity_pool_provider.github]
}

resource "google_service_account_iam_member" "deployer_token_creator" {
  for_each = local.deployers

  service_account_id = each.value.service_account_id
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = each.value.principal

  depends_on = [google_iam_workload_identity_pool_provider.github]
}
