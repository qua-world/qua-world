# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

locals {
  # The hosted world server gets projects of its own, so this one holds only
  # what Terraform needs to run.
  project_id = "qua-world-infrastructure"

  # One bucket per layer, each named after the layer it serves. Each layer's
  # backend.tf repeats its own literal, because backend blocks cannot
  # interpolate.
  bootstrap_state_bucket      = "qua-world-tfstate"
  infrastructure_state_bucket = "qua-world-infrastructure-tfstate"

  github_repository = "qua-world/qua-world"

  # scripts/bootstrap.sh repeats this literal as LOCATION; shell cannot read a
  # Terraform local.
  region = "europe-west2"

  # The App ID and installation ID are not secret. They live here because none
  # of the three exists until the App is registered, which leaves
  # terraform/infrastructure/ nothing to hardcode.
  github_app_secrets = toset([
    "github-app-id",
    "github-app-installation-id",
    "github-app-private-key",
  ])
}
