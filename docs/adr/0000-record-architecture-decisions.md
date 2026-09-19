<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# 0. Record architecture decisions

## Status

Proposed

## Context

Architecturally significant decisions accrue as this project grows. The
client/server split, the wire protocol's shape, the simulation substrate, the
world-store representation, the effect system, and the publication channel are
all open questions in the tracker (#26, #28, #36, #40, #41, #43). Left
unrecorded, the reasoning behind each choice lives only in issue threads and
pull request discussions, where later readers don't find it and the argument
reopens.

Recording why a decision was made, including the forces in play and the
alternatives weighed, lets a later contributor follow the decision instead of
rediscovering it.

## Decision

We will record architecturally significant decisions as Architecture Decision
Records, following the format [Michael Nygard set out][nygard].

Each record is one Markdown file under `docs/adr/`, named `NNNN-kebab-title.md`
with a four-digit sequence number that increases by one per record. Each
carries four sections: Status, Context, Decision, and Consequences.

A record is warranted when a decision is both significant and hard to reverse:
it sets a precedent others follow, locks in a dependency, shapes a public API,
or picks between non-trivial alternatives. Tactical, reversible choices stay in
commit messages and pull request descriptions.

A new record opens as `Proposed`. The maintainer promotes it to `Accepted` once
the decision is made, or marks it `Superseded by NNNN` or `Deprecated` as it
evolves.

This file is record 0, the practice itself.

## Consequences

Decisions gain a single searchable home, and an issue thread can point at a
record instead of explaining the context again.

Records are append-only history rather than living documentation. A decision
that changes gets a new record superseding the old one, and the original stays
in place as what was true at the time. A reader who wants current state reads
the newest record on a topic, not the whole directory.

The cost is the discipline of writing one when a decision qualifies, and the
judgment to skip one when it doesn't. Recording too much dilutes the
collection.

[nygard]: https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions
