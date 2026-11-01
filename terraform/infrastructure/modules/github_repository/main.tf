# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

locals {
  develop_branch = "develop"
  master_branch  = "master"

  # A literal ref, because ~DEFAULT_BRANCH would move develop's rules to
  # whichever branch became the default.
  develop_refs = ["refs/heads/${local.develop_branch}"]

  # A squashed release shares no ancestry with develop, so the next release
  # re-presents its changes as conflicts. Release branches become master,
  # so they take master's protections.
  flow = var.legacy.squash_only ? {
    branches       = []
    merge_methods  = ["squash"]
    linear_history = true
    release_refs   = []
    } : {
    branches       = [local.master_branch]
    merge_methods  = ["merge"]
    linear_history = false
    release_refs   = ["refs/heads/${local.master_branch}", "refs/heads/release/**"]
  }

  protected_refs = concat(local.develop_refs, local.flow.release_refs)
  has_rulesets   = !var.legacy.unprotected

  merge_methods = coalesce(var.legacy.merge_methods, local.flow.merge_methods)
}

# Public because the org is on GitHub Free, where a private repository cannot
# have rulesets. Dependabot alerts come from the org's enforced code security
# configuration, which the provider cannot override per repository.
resource "github_repository" "this" {
  name         = var.name
  description  = var.description
  homepage_url = var.homepage_url
  topics       = var.topics

  visibility                  = "public"
  has_issues                  = true
  has_projects                = false
  has_wiki                    = false
  has_discussions             = var.has_discussions
  allow_merge_commit          = contains(local.merge_methods, "merge")
  allow_squash_merge          = contains(local.merge_methods, "squash")
  allow_rebase_merge          = false
  allow_auto_merge            = var.renovate_automerge
  allow_update_branch         = var.legacy.allow_update_branch
  squash_merge_commit_title   = var.legacy.squash_merge_commit_title
  squash_merge_commit_message = var.legacy.squash_merge_commit_message
  merge_commit_title          = "MERGE_MESSAGE"
  merge_commit_message        = "PR_TITLE"
  delete_branch_on_merge      = true
  archive_on_destroy          = true
}

resource "github_branch_default" "this" {
  repository = github_repository.this.name
  branch     = local.develop_branch
}

resource "github_branch" "long_lived" {
  for_each = toset(local.flow.branches)

  repository    = github_repository.this.name
  branch        = each.key
  source_branch = local.develop_branch

  depends_on = [github_branch_default.this]
}

# Rulesets, because classic branch protection has no bypass actors. A bypass
# applies to a whole ruleset, so each ruleset holds one policy and a bypass
# skips only that policy.

locals {
  # Mode "always" lets the admin push directly, not only merge.
  admin_actor = {
    actor_id    = 5 # built-in repository "admin" role
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }

  renovate_actor = {
    actor_id   = 2740 # GET /apps/renovate
    actor_type = "Integration"
  }

  admin_bypass = [local.admin_actor]

  # Mode "pull_request" lets Renovate merge its pull requests without letting
  # it push to develop.
  merge_bypass = concat(
    local.admin_bypass,
    var.renovate_automerge ? [merge(local.renovate_actor, { bypass_mode = "pull_request" })] : [],
  )

  # Renovate pushes to its branches directly, so it needs mode "always" there.
  renovate_branch_bypass = [
    local.admin_actor,
    merge(local.renovate_actor, { bypass_mode = "always" }),
  ]
}

resource "github_repository_ruleset" "default" {
  count = local.has_rulesets ? 1 : 0

  name        = "default"
  repository  = github_repository.this.name
  target      = "branch"
  enforcement = "active"

  depends_on = [github_branch_default.this]

  conditions {
    ref_name {
      include = local.protected_refs
      exclude = []
    }
  }

  dynamic "bypass_actors" {
    for_each = local.admin_bypass
    content {
      actor_id    = bypass_actors.value.actor_id
      actor_type  = bypass_actors.value.actor_type
      bypass_mode = bypass_actors.value.bypass_mode
    }
  }

  # No required_signatures: GitHub signs the merges it makes, so the rule
  # would only block unsigned direct pushes.
  rules {
    deletion                = true
    non_fast_forward        = true
    required_linear_history = local.flow.linear_history
  }
}

# Merging a pull request updates the branch too, so only bypass actors can
# merge.
resource "github_repository_ruleset" "admin_only" {
  count = local.has_rulesets && var.admin_only_updates ? 1 : 0

  name        = "admin-only"
  repository  = github_repository.this.name
  target      = "branch"
  enforcement = "active"

  depends_on = [github_branch_default.this]

  conditions {
    ref_name {
      include = local.protected_refs
      exclude = []
    }
  }

  dynamic "bypass_actors" {
    for_each = local.merge_bypass
    content {
      actor_id    = bypass_actors.value.actor_id
      actor_type  = bypass_actors.value.actor_type
      bypass_mode = bypass_actors.value.bypass_mode
    }
  }

  rules {
    update = true
  }
}

# The admin bypasses because a solo maintainer can't satisfy a required review.
resource "github_repository_ruleset" "review" {
  count = local.has_rulesets ? 1 : 0

  name        = "review"
  repository  = github_repository.this.name
  target      = "branch"
  enforcement = "active"

  depends_on = [github_branch_default.this]

  conditions {
    ref_name {
      include = local.protected_refs
      exclude = []
    }
  }

  dynamic "bypass_actors" {
    for_each = local.merge_bypass
    content {
      actor_id    = bypass_actors.value.actor_id
      actor_type  = bypass_actors.value.actor_type
      bypass_mode = bypass_actors.value.bypass_mode
    }
  }

  rules {
    # Code owner review applies even with a review count of 0.
    pull_request {
      allowed_merge_methods             = local.merge_methods
      required_approving_review_count   = 0
      require_code_owner_review         = var.require_code_owner_review
      required_review_thread_resolution = true
    }
  }
}

data "github_app" "actions" {
  slug = "github-actions"
}

locals {
  # A Git flow repository must run a job by this name, because rulesets on
  # GitHub Free cannot restrict a pull request's source branch. It fails a
  # pull request into master from anything but release/* or hotfix/*.
  git_flow_source_check = "Check Git flow source branch"

  required_checks = var.required_status_checks == null ? [] : concat(
    var.required_status_checks.ci_results_check ? ["Check CI results"] : [],
    var.required_status_checks.contexts,
  )

  # Requiring up-to-date branches makes Renovate rebase whenever the target
  # moves. Each rebase can pull a newer release and restart its
  # minimumReleaseAge wait, so the pull request may never merge. Renovate
  # never targets release refs, so they avoid the loop.
  checks_refs = {
    for name, policy in {
      develop = {
        refs     = local.develop_refs
        contexts = local.required_checks
        strict   = coalesce(try(var.required_status_checks.strict, null), !var.renovate_automerge)
      }
      release = {
        refs     = local.flow.release_refs
        contexts = concat([local.git_flow_source_check], local.required_checks)
        strict   = true
      }
    } : name => policy if local.has_rulesets && length(policy.refs) > 0 && length(policy.contexts) > 0
  }
}

# No bypass actors: a merge that bypasses any ruleset skips every rule its
# merger can bypass, so merges past admin-only would skip these checks too.
resource "github_repository_ruleset" "checks" {
  for_each = local.checks_refs

  name        = "checks-${each.key}"
  repository  = github_repository.this.name
  target      = "branch"
  enforcement = "active"

  # Creating master from develop fails once the release checks exist:
  # develop's commits never carry the Git flow source check.
  depends_on = [github_branch_default.this, github_branch.long_lived]

  conditions {
    ref_name {
      include = each.value.refs
      exclude = []
    }
  }

  rules {
    required_status_checks {
      strict_required_status_checks_policy = each.value.strict

      dynamic "required_check" {
        for_each = each.value.contexts
        content {
          context = required_check.value
          # Stops another app from satisfying the check by reporting under
          # the same name.
          integration_id = data.github_app.actions.id
        }
      }
    }
  }
}

# Without this, anyone who can push to a Renovate branch could add commits to a
# pull request Renovate then merges past review.
resource "github_repository_ruleset" "renovate" {
  count = var.renovate_automerge ? 1 : 0

  name        = "renovate"
  repository  = github_repository.this.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/heads/renovate/**"]
      exclude = []
    }
  }

  dynamic "bypass_actors" {
    for_each = local.renovate_branch_bypass
    content {
      actor_id    = bypass_actors.value.actor_id
      actor_type  = bypass_actors.value.actor_type
      bypass_mode = bypass_actors.value.bypass_mode
    }
  }

  rules {
    update = true
  }
}

# A tag push can publish to a registry that can't recall an upload, so a moved
# tag leaves the registry and the repository silently disagreeing. The admin
# bypass keeps a botched tag fixable.
resource "github_repository_ruleset" "immutable_tags" {
  count = local.has_rulesets ? 1 : 0

  name        = "immutable-tags"
  repository  = github_repository.this.name
  target      = "tag"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~ALL"]
      exclude = []
    }
  }

  dynamic "bypass_actors" {
    for_each = local.admin_bypass
    content {
      actor_id    = bypass_actors.value.actor_id
      actor_type  = bypass_actors.value.actor_type
      bypass_mode = bypass_actors.value.bypass_mode
    }
  }

  # No non_fast_forward: update already blocks force pushes.
  rules {
    deletion = true
    update   = true
  }
}

# Off because Renovate already fixes the advisories Dependabot alerts raise.
# Declared so enabling it in the UI drifts back off.
resource "github_repository_dependabot_security_updates" "this" {
  repository = github_repository.this.name
  enabled    = var.legacy.dependabot_security_updates
}

# Applies only to jobs without a permissions: block.
resource "github_workflow_repository_permissions" "this" {
  repository                       = github_repository.this.name
  default_workflow_permissions     = "read"
  can_approve_pull_request_reviews = var.legacy.can_approve_pull_request_reviews
}

# Declared because destroying it resets the repository to allow every action,
# whatever the org allowlist says. GitHub rejects "all" under an org that
# selects actions, so each repository repeats the org's allowlist.
resource "github_actions_repository_permissions" "this" {
  repository      = github_repository.this.name
  allowed_actions = "selected"

  allowed_actions_config {
    github_owned_allowed = true
    verified_allowed     = true
    patterns_allowed     = coalesce(var.legacy.allowed_action_patterns, var.org_allowed_action_patterns)
  }
}

data "github_user" "reviewer" {
  for_each = toset(flatten([for env in values(var.environments) : env.reviewers]))

  username = each.key
}

resource "github_repository_environment" "this" {
  for_each = var.environments

  repository        = github_repository.this.name
  environment       = each.key
  can_admins_bypass = each.value.can_admins_bypass

  dynamic "reviewers" {
    for_each = length(each.value.reviewers) > 0 ? [1] : []
    content {
      users = [for login in each.value.reviewers : tonumber(data.github_user.reviewer[login].id)]
    }
  }

  dynamic "deployment_branch_policy" {
    for_each = length(each.value.deployment_branches) > 0 ? [1] : []
    content {
      protected_branches     = false
      custom_branch_policies = true
    }
  }
}

resource "github_repository_environment_deployment_policy" "this" {
  for_each = merge([
    for env_name, env in var.environments : {
      for pattern in env.deployment_branches :
      "${env_name}:${pattern}" => { environment = env_name, pattern = pattern }
    }
  ]...)

  repository     = github_repository.this.name
  environment    = github_repository_environment.this[each.value.environment].environment
  branch_pattern = each.value.pattern
}
