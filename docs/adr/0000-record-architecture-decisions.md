# 0. Record architecture decisions

## Status

Proposed

## Context

Architecturally significant decisions accrue as this project grows: the
client/server split, per-side language choices, the wire protocol's shape, the
simulation model, and the impure-layer effect strategy are all under active
discussion (issues #26, #28, #36, #40, #41, #43). Left unrecorded, the reasoning
behind each choice lives only in issue threads and pull-request discussions,
where it is hard to find later and easy to relitigate.

We need a lightweight, durable place to capture *why* a decision was made — the
forces in play and the alternatives weighed — so that future contributors can
follow the North Star rather than rediscover it.

## Decision

We will record architecturally significant decisions as Architecture Decision
Records (ADRs), following [Michael Nygard's
format](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions).

ADRs live in `docs/adr/`, one Markdown file per decision, named
`NNNN-kebab-title.md` with a monotonically increasing four-digit sequence
number. Each ADR has four sections: **Status**, **Context**, **Decision**, and
**Consequences**. A new ADR opens as `Proposed`; the team promotes it to
`Accepted` once the decision is made, or marks it `Superseded by NNNN` /
`Deprecated` as it evolves.

This file is ADR 0 — the record of the practice itself.

## Consequences

- Decisions gain a single, greppable home; issue threads can point at an ADR
  instead of re-explaining context.
- Every significant decision carries a small authoring cost. Tactical,
  easily-reversed choices stay in commit messages and pull-request descriptions
  — over-recording dilutes the collection's value.
- ADRs are append-only history, not living documentation. A decision that
  changes gets a new ADR that supersedes the old one; the original stays in
  place as the historical record.
