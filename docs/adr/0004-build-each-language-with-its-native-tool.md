<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# 4. Build each language with its native tool

## Status

Accepted

## Context

The monorepo ([record 1](0001-keep-qua-world-in-one-monorepo.md)) holds a
Haskell client today and an Erlang world-server
([record 2](0002-run-an-authoritative-world-server-on-erlang.md)) later. The
build tool has to handle both languages. It also has to stay cheap enough to
run in CI and quick for contributors to pick up. Build definitions spread
across every target, so changing tools later is expensive.

Three candidates:

- **Bazel.** `rules_haskell` supports GHC 9.10, but its last release was v1.0
  in September 2024. `rules_erlang` is archived, and so is its only fork.
  RabbitMQ, which wrote it, dropped Bazel for Make and `erlang.mk` in
  March 2025.
- **buck2.** Its prelude ships maintained Erlang rules and Haskell rules. The
  Haskell rules are undocumented and have no listed maintainer. Hackage
  dependencies need `cabal-buck2`, first released in 2026. Every buck2 release
  is a prerelease, and its README warns outside users of rough edges.
- **`cabal` and `rebar3`.** Each is its language's default build tool. Neither
  sees the other's targets, and neither offers remote execution.

Bazel's and buck2's main advantages over native builds count for little here:

- Target visibility would enforce record 1's client–server boundary. Client and
  server are written in different languages, so neither can depend on the
  other's internals anyway.
- Shared caching and remote execution pay off on long builds. Build and test
  of the client take under 30 seconds in CI; installing GHC takes most of the
  job (#144).

## Decision

Each language builds with its own tool: `cabal` for Haskell and `rebar3` for
Erlang. When the server target lands, a `justfile` at the repository root runs
both and any step that spans them, such as the protocol compatibility check
(#28).

Revisit this when buck2 publishes stable releases and documents its Haskell
support, or when cross-language build time becomes a measured cost.

## Consequences

- Contributors use the tools their language's documentation already covers.
  CI installs each language's compiler and build tool with its standard action.
- There's no single build graph. A protocol change rebuilds each side
  separately, and the `justfile` has to order steps that cross languages.
- Nothing caches build outputs across languages, and nothing runs builds
  remotely. CI time depends on caching each compiler and its dependencies
  (#144).
- The client–server boundary holds because the two sides are in different
  languages, not because the build checks it.
