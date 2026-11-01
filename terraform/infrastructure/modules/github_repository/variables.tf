# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

variable "name" {
  type        = string
  description = "Repository name (the GitHub repository slug)."
}

variable "description" {
  type        = string
  default     = ""
  description = "Short repository description."
}

variable "homepage_url" {
  type        = string
  default     = null
  description = "Optional homepage URL surfaced on the repository page."
}

variable "topics" {
  type        = list(string)
  default     = []
  description = "GitHub topics applied to the repository."
}

variable "org_allowed_action_patterns" {
  type        = list(string)
  description = <<-EOT
    The org's Actions allowlist patterns. Read them from the org
    permissions resource so the org allowlist applies first.
  EOT
}

variable "required_status_checks" {
  type = object({
    ci_results_check = optional(bool, false)
    contexts         = optional(list(string), [])
    strict           = optional(bool)
  })
  default     = null
  description = <<-EOT
    Status checks that must pass before merging into develop, master, or
    release/**. Omit to leave develop ungated.

    contexts are GitHub Actions check-run names, each unique on a pull
    request. A missing check blocks every merge, the admin's included,
    so leave out path-gated jobs. A check must fail only on what the pull
    request changes, so leave out dependency scans: they fail on newly
    disclosed advisories.

    strict requires a pull request into develop to be up to date; master
    and release/** always require it. It defaults to false under
    renovate_automerge, true otherwise.

    ci_results_check requires the aggregator job "Check CI results"
    instead of matrix legs, whose names change with the versions they
    test. The job must list every job it stands in for under needs: and
    run on pushes to develop.
  EOT
}

variable "require_code_owner_review" {
  type        = bool
  default     = false
  description = <<-EOT
    Require a code owner's approval before merging into develop, master, or
    release/**. Gates only pull requests that change a path
    .github/CODEOWNERS assigns.
  EOT
}

variable "admin_only_updates" {
  type        = bool
  default     = true
  description = <<-EOT
    Only the repository admin, and Renovate under renovate_automerge, can
    push or merge to develop, master, or release/**. Set false once others
    merge pull requests.
  EOT
}

variable "renovate_automerge" {
  type        = bool
  default     = false
  description = <<-EOT
    Renovate merges its own pull requests without review once the required
    status checks pass; GitHub auto-merge ignores checks that aren't
    required. Only Renovate can push to renovate/**.
  EOT

  validation {
    condition     = !var.renovate_automerge || var.required_status_checks != null
    error_message = "renovate_automerge needs required_status_checks; without them Renovate would merge on nothing."
  }
}

variable "has_discussions" {
  type        = bool
  default     = false
  description = "Enable GitHub Discussions on the repository."
}

variable "environments" {
  type = map(object({
    deployment_branches = optional(list(string), [])
    reviewers           = optional(list(string), [])
    can_admins_bypass   = optional(bool, true)
  }))
  default     = {}
  description = <<-EOT
    Deployment environments, keyed by name, each scoping its own secrets
    for workflows that declare `environment: <name>`.

    deployment_branches lists the only refs whose jobs can use the
    environment and read its secrets. Empty admits any ref.

    reviewers lists GitHub logins, any one of whom must approve a job
    before it can use the environment. Empty requires no approval.

    can_admins_bypass lets repository admins skip the environment's
    protections, reviewers included.
  EOT
}

variable "legacy" {
  type = object({
    squash_only                      = optional(bool, false)
    unprotected                      = optional(bool, false)
    merge_methods                    = optional(list(string))
    allow_update_branch              = optional(bool, true)
    squash_merge_commit_title        = optional(string, "PR_TITLE")
    squash_merge_commit_message      = optional(string, "PR_BODY")
    allowed_action_patterns          = optional(list(string))
    can_approve_pull_request_reviews = optional(bool, false)
    dependabot_security_updates      = optional(bool, false)
  })
  default     = {}
  nullable    = false
  description = <<-EOT
    Pre-Terraform settings a repository keeps in place of org defaults.
    Omit it once the repository adopts them all.

    squash_only: squash merges and no master branch, in place of Git
    flow's merge commits and protected master and release/**.

    unprotected: no rulesets, in place of the default, admin-only, review,
    checks, and immutable-tags rulesets.

    merge_methods: the merge methods the repository allows, from "merge"
    and "squash", in place of the one its flow picks.

    allow_update_branch: false hides a pull request's button for merging
    its base branch in.

    squash_merge_commit_title, squash_merge_commit_message: GitHub's
    values for a squash commit's title and message, in place of the pull
    request's title and body.

    allowed_action_patterns: owner/repo@* patterns for a repository
    allowlist inside the org's, in place of org_allowed_action_patterns.
    GitHub-owned and verified-creator actions stay allowed.

    can_approve_pull_request_reviews: workflows' GITHUB_TOKEN may create
    and approve pull requests.

    dependabot_security_updates: Dependabot opens security fix pull
    requests.
  EOT
}
