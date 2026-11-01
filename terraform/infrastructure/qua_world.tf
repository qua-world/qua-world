# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

module "qua_world" {
  source = "./modules/github_repository"

  name        = local.github_repository_name
  description = "GUI Client and Client Interfaces for qua.world"
  topics      = ["client", "game", "haskell", "mmo"]

  org_allowed_action_patterns = tolist(github_actions_organization_permissions.org.allowed_actions_config[0].patterns_allowed)

  required_status_checks    = { ci_results_check = true }
  require_code_owner_review = true
  renovate_automerge        = true

  legacy = {
    merge_methods               = ["merge", "squash"]
    allow_update_branch         = false
    squash_merge_commit_title   = "COMMIT_OR_PR_TITLE"
    squash_merge_commit_message = "COMMIT_MESSAGES"
    dependabot_security_updates = true
  }
}

import {
  to = module.qua_world.github_repository.this
  id = local.github_repository_name
}

import {
  to = module.qua_world.github_branch_default.this
  id = local.github_repository_name
}

# The third field sets source_branch, which otherwise imports as "main" and
# forces a replacement.
import {
  to = module.qua_world.github_branch.long_lived["master"]
  id = "${local.github_repository_name}:master:develop"
}

import {
  to = module.qua_world.github_repository_dependabot_security_updates.this
  id = local.github_repository_name
}

import {
  to = module.qua_world.github_workflow_repository_permissions.this
  id = local.github_repository_name
}

import {
  to = module.qua_world.github_actions_repository_permissions.this
  id = local.github_repository_name
}
