# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

# Each import block is idempotent once its resource is in state, so it stays.
import {
  to = github_organization_settings.org
  # The organization's numeric ID; this resource doesn't import by login.
  id = "65674695"
}

resource "github_organization_settings" "org" {
  billing_email = "alunduil@gmail.com"
  name          = "Qua World"
  description   = "Open MMO"

  default_repository_permission = "read"

  # Only owners create repositories.
  members_can_create_repositories         = false
  members_can_create_public_repositories  = false
  members_can_create_private_repositories = false
  members_can_fork_private_repositories   = false

  # The *_enabled_for_new_repositories fields stay at their false defaults. The
  # org's code security configuration sets those features on new repositories,
  # and supersedes these older fields.
}

import {
  to = github_actions_organization_permissions.org
  id = local.github_owner
}

resource "github_actions_organization_permissions" "org" {
  allowed_actions      = "selected"
  enabled_repositories = "all"
  sha_pinning_required = true

  allowed_actions_config {
    github_owned_allowed = true
    verified_allowed     = true

    # Actions outside GitHub's own, including those a composite action calls.
    # `@*` admits any ref, and sha_pinning_required then demands a SHA.
    patterns_allowed = [
      "8c6794b6/hpc-codecov-action@*",
      "astral-sh/setup-uv@*",
      "bats-core/bats-action@*",
      "codecov/codecov-action@*",
      "google-github-actions/auth@*",
      "google-github-actions/get-secretmanager-secrets@*",
      "google-github-actions/setup-gcloud@*",
      "hashicorp/setup-terraform@*",
      "haskell-actions/hlint-setup@*",
      "haskell-actions/setup@*",
      "tox-dev/action-pre-commit-uv@*",
    ]
  }
}

import {
  to = github_actions_organization_workflow_permissions.org
  id = local.github_owner
}

resource "github_actions_organization_workflow_permissions" "org" {
  organization_slug                = local.github_owner
  default_workflow_permissions     = "read"
  can_approve_pull_request_reviews = false
}

# The org holds this repository alone; anything else arrived unplanned.
# fork:true admits forks, which search otherwise omits. A check warns rather
# than fails, so an unexpected repository never blocks an apply.
check "org_holds_only_qua_world" {
  data "github_repositories" "org" {
    query = "org:${local.github_owner} fork:true"
  }

  assert {
    condition     = toset(data.github_repositories.org.full_names) == toset([local.github_repository])
    error_message = "Expected only ${local.github_repository} in the organization, found: ${join(", ", data.github_repositories.org.full_names)}"
  }
}
