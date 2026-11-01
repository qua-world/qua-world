# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

terraform {
  backend "gcs" {
    bucket = "qua-world-infrastructure-tfstate"
    prefix = "infrastructure"
  }
}
