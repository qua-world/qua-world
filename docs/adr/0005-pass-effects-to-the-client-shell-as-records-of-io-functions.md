<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# 5. Pass effects to the client shell as records of IO functions

## Status

Accepted

## Context

The Haskell client keeps its world model (`Partir.World.*`) and agents
(`Partir.Agent.*`) free of `IO`. An agent decides through a pure
`step :: WorldView -> a -> (a, [Intent])`, and its caller carries out the
intents. The shell around them isn't pure: the network session (#13), the
WebSocket proxy (#14), the cell hand-off (#27), the simulation loop (#15), and
the client main loop all deal with sockets, timers, and windowing. The Haskell
SDK that the headless bot (#21) runs on has the same effects.
[Record 3](0003-connect-every-actor-as-a-client-on-an-sdk.md) makes every
actor an SDK client, so SDK users meet the effect style wherever they start a
bot, run it, or replace its transport or clock in a test.

None of these modules exists yet, and the first to land would set the effect
style for the rest. The Erlang server
([record 2](0002-run-an-authoritative-world-server-on-erlang.md)) and SDKs in
other languages are out of scope.

SDK users include newcomers to Haskell, experienced Haskell programmers, bots
written by language models, and the client team itself. Where their needs conflict,
newcomers decide. The criteria come from Clarke's API usability dimensions
([Measuring API Usability](https://jacobfilipp.com/DrDobbs/articles/DDJ/2004/0405/0405j/0405j.htm))
and Green and Blackwell's
[cognitive dimensions](https://www.cl.cam.ac.uk/~afb21/CognitiveDimensions/CDtutorial.pdf):

- **Domain correspondence**: the API reads in domain terms, not library terms.
- **Consistency**: the client and the SDK share one notation, and it carries
  over to SDKs in other languages.
- **Learning cost**: what a user learns before a first bot runs.
- **Premature commitment**: whether user code must adopt the SDK's effect
  library.
- **Viscosity**: what adding one capability to existing code changes.
- **Progressive evaluation**: part of a program runs against fakes.
- **Error-proneness**: what a common mistake looks like, and how readable its
  error is.

A candidate also has to build on the pinned GHC 9.10.3 and have had a release
in the last 24 months. These fail that gate:

- `effet`, `extensible-effects`, `freer-simple`, and `simple-effects` don't
  compile on GHC 9.10.3. The newest `freer-simple` release doesn't resolve, and
  the older one the solver picks doesn't compile.
- `cleff` caps `template-haskell` below the version GHC 9.10.3 ships.
- `in-other-words`, `eveff`, and `freer-effects` compile, but their last
  releases were in 2022, 2021, and 2017.

The rest differ in what they put in front of a user. For a function that looks
around, then moves or speaks:

| Style | Signature | Missing capability | Lines to add one |
| --- | --- | --- | --- |
| One record per domain noun | `Body -> IO ()` | can't happen | 1 |
| One record per capability | `Eyes -> Legs -> Voice -> IO ()` | 7 lines, not in scope | 5 |
| `bluefin` | `(e1 :> es, …) => Eyes e1 -> … -> Eff es ()` | 5 lines, not in scope | 4 |
| `mtl` | `(MonadEyes m, …) => m ()` | 19 lines, can't deduce | 2 |
| `effectful` | `(Eyes :> es, …) => Eff es ()` | 17 lines, can't deduce | 2 |
| `polysemy` | `Members '[Eyes, …] r => Sem r ()` | 17 lines, can't deduce | 2 |
| `fused-effects` | `(Has Eyes sig m, …) => m ()` | 18 lines, can't deduce | 2 |
| `heftia-effects` | `(Eyes :> es, …) => Eff es ()` | 24 lines of library internals | 2 |

`rio` is the record style inside a `ReaderT` environment, and `capability` is
the `mtl` style.

- The line counts are for one function with one call site. Constraint styles
  change every signature in a call chain. One record per capability also
  changes every call site. One record per domain noun changes neither.
- Every effect library puts its own types in user signatures and needs its own
  import in user code. `polysemy` also needs `DataKinds`.
- Records map onto objects in other languages, as in `body.move(North)`.
- Every style runs against fakes. A record fake runs in `IO`; an effect
  library's fake can run pure.

Records named for domain nouns lead or tie on every criterion except
progressive evaluation, where they still run against fakes. They remove the
missing-capability mistake instead of reporting it.

## Decision

Agents stay pure: an agent's logic is a `Partir.Agent.Class` instance, with no
effects.

The Haskell client shell and the Haskell SDK run in plain `IO`. An effect is a
record of `IO` functions, named for a domain noun and passed whole as an
argument. Capabilities that travel together share one record (Introduce
Parameter Object, Preserve Whole Object). Neither uses an effect library,
`mtl`-style effect classes, or a `ReaderT` environment.

`Partir.World.*`, `Partir.Agent.*`, and the wire types in
`Partir.Net.Protocol` (#12) stay pure and take no effect records. How an
agent performs I/O while deciding is #184.

## Consequences

- A newcomer writes a bot from a pure `Agent` instance, `IO`, and records. Bot
  code needs no language extensions and no effect-library types.
- The same records map onto objects in the SDKs for other languages.
- A test fake is an ordinary record value, and it runs in `IO`.
- A record that bundles capabilities hides which of them a function uses. Its
  type doesn't list them, and the compiler can't report one as missing.
- A later move to `effectful` or `bluefin` maps each record field onto an
  `effectful` effect constructor or a field of a `bluefin` handle.
