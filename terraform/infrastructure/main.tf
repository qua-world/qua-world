# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

terraform {
  required_version = ">= 1.7"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }
}

# The token comes from GITHUB_TOKEN, which CI fills with a GitHub App
# installation token.
provider "github" {
  owner = local.github_owner
}
