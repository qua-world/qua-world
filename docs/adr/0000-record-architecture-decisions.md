<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# 0. Record architecture decisions

## Status

Accepted

## Context

Several decisions that shape qua.world as a whole are open in the tracker.
They include the client/server split (#26), the wire protocol's shape (#28),
publication (#36), simulation stepping (#40), the world store (#41), and the
effect system (#43).
Left in issue threads and pull-request reviews, the reasoning behind each
choice is hard to find later and tempting to argue again.

## Decision

Architecturally significant decisions go in Architecture Decision Records in
the format from [Documenting Architecture
Decisions](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions).

- Records live in `docs/adr/`, one Markdown file per decision, named
  `NNNN-kebab-title.md` with the next four-digit sequence number.
- Each record has four sections: Status, Context, Decision, and Consequences.
- The pull request is the proposal. Review happens there, and a record merges
  with the status `Accepted`.
- An accepted record changes only its status. A changed decision gets a new
  record, and the old one becomes `Superseded by NNNN`. A decision that no
  longer applies, with nothing replacing it, becomes `Deprecated`.

## Consequences

- Issues and reviews can point at a record instead of restating its context.
- Each record costs some writing, so choices that are tactical or cheap to
  reverse stay in commit messages and pull-request descriptions.
- The collection is history: reading the current architecture means following
  each `Superseded by` link to the newest record.
