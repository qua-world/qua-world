# SPDX-FileCopyrightText: 2026 Alex Brandt
#
# SPDX-License-Identifier: MIT

# Anything split per role keys off this map, so the pairing is stated once. A
# pairing restated elsewhere could hand plan a write credential unnoticed.
locals {
  deployers = {
    ro = google_service_account.github_deployer_ro.email
    rw = google_service_account.github_deployer_rw.email
  }
}
