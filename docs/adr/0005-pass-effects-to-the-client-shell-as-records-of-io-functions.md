<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# 5. Pass effects to the client shell as records of IO functions

## Status

Accepted

## Context

The Haskell client keeps its world model (`Partir.World.*`) and agents
(`Partir.Agent.*`) free of `IO`. The shell around them isn't: the network
session (#13), the WebSocket proxy (#14), the cell hand-off (#27), the
simulation loop (#15), and the client main loop all deal with sockets, timers,
and windowing. The Haskell SDK that the headless bot (#21) runs on has the same
effects. [Record 3](0003-connect-every-actor-as-a-client-on-an-sdk.md) makes
every actor an SDK client, so the SDK's effect style becomes part of its public
interface.

None of these modules exists yet. Whichever lands first would set the effect
style for the rest, so the style is chosen here. The Erlang server
([record 2](0002-run-an-authoritative-world-server-on-erlang.md)) and SDKs in
other languages are out of scope.

The choice had to meet three requirements:

- Tests swap a real effect for a fake one, such as a fake transport for #13's
  handshake and reconnect, or a fake clock for #15.
- Every shell module and the SDK follow the same convention.
- The library builds on the pinned GHC 9.10.3 and has had a release in the last
  24 months.

Each candidate was compiled against GHC 9.10.3. Every surviving option
except `rio` and `capability` also ran the same probe: a clock effect that a
pure test replaces with a fixed time.
Nine candidates meet all three requirements. They differ in what a fake costs
to write:

- **Records of `IO` functions**, using only `base`. A fake is another record
  value. `rio` packages the same pattern inside a `ReaderT` environment.
- **`mtl`-style classes**, using `mtl` or `capability`. Each fake needs a
  `newtype` and an instance.
- **IO-based effect libraries**: `effectful` and `bluefin`. An `effectful` fake
  is an interpreter function, and a `bluefin` fake is a handle value.
- **Free and higher-order effect libraries**: `polysemy`, `fused-effects`, and
  `heftia-effects`. A `polysemy` or `heftia-effects` fake is an interpreter
  function. A `fused-effects` fake is a carrier `newtype` with an `Algebra`
  instance. `heftia-effects` generated code needs `AllowAmbiguousTypes`.

The rest failed a requirement:

- `effet`, `extensible-effects`, `freer-simple`, and `simple-effects` don't
  compile on GHC 9.10.3. Hackage's newest `freer-simple` doesn't resolve at
  all, and the older one it falls back to doesn't compile.
- `cleff` caps `template-haskell` below the version GHC 9.10.3 ships.
- `in-other-words`, `eveff`, and `freer-effects` compile, but their last
  releases were in 2022, 2021, and 2017.

Since nothing in the requirements separates the nine, the simplest one wins.

## Decision

The Haskell client shell and the Haskell SDK run in plain `IO`. Each effect that
a test needs to replace is a record of `IO` functions, and a function that
uses the effect takes the record as an argument. The shell uses no effect
library, no `mtl`-style effect classes, and no `ReaderT` environment.

`Partir.World.*` and `Partir.Agent.*` stay pure and take no effect records.
`Partir.Net.Protocol` (#12) is pure wire types, so this record doesn't cover
it.

## Consequences

- A test fake is an ordinary record value. Tests need no extra library and no
  instances.
- Bot authors using the SDK see plain `IO` and records, not a library's effect
  types.
- The compiler doesn't track which effects a function performs. A reader learns
  that from the records the function takes.
- A function that needs several effects takes several records. If that
  argument list becomes a measured cost, revisit this decision.
- A record of `IO` functions maps one-to-one onto an `effectful` interpreter or
  a `bluefin` handle, so switching to one of them later is a mechanical
  rewrite.
