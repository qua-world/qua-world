# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

locals {
  # Holds only what Terraform needs to run; game servers get their own projects.
  project_id = "qua-world-infrastructure"

  # Each layer's backend.tf repeats its bucket's name, because backend blocks
  # cannot interpolate.
  bootstrap_state_bucket      = "qua-world-tfstate"
  infrastructure_state_bucket = "qua-world-infrastructure-tfstate"

  github_repository = "qua-world/qua-world"

  # scripts/bootstrap.sh repeats this literal as LOCATION; shell cannot read a
  # Terraform local.
  region = "europe-west2"
}
