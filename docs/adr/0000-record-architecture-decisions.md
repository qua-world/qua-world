# 0. Record architecture decisions

## Status

Proposed

## Context

qua.world's client has several architecturally significant choices ahead of it
— the client/server split, the wire-protocol shape, the simulation substrate,
the world-store representation, the effect system, and the dialogue runtime. The
issue tracker already earmarks these as decisions to record (#26, #28, #40, #41,
#43). Without a durable home, the rationale for each — especially the rejected
alternatives — scrolls out of the tracker and is lost to future contributors.

## Decision

We will record architecturally significant decisions as Architecture Decision
Records, following Michael Nygard's format, one Markdown file per decision under
`docs/adr/`, numbered sequentially (`NNNN-kebab-title.md`).

An ADR is warranted when a decision is both significant and hard to reverse:
sets precedent, locks in a dependency, shapes a public API, or picks between
non-trivial alternatives. Tactical, easily-reversed choices stay in commit
messages and PR descriptions.

A new ADR starts at `Proposed`; a maintainer promotes it to `Accepted`, or later
to `Superseded by NNNN` / `Deprecated`.

## Consequences

The rationale behind a decision — including the alternatives weighed and
rejected — survives where a contributor can find it, keyed to the code and
issues it governs. The cost is the discipline of writing one when a decision
qualifies, and the judgement to *not* write one when it doesn't: ADR sprawl
makes the collection worth less.
