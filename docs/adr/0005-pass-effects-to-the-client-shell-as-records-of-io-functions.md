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

None of these modules exists yet, and the first to land would set the effect
style for the rest. The Erlang server
([record 2](0002-run-an-authoritative-world-server-on-erlang.md)) and SDKs in
other languages are out of scope.

The choice had to meet three requirements:

- Tests swap a real effect for a fake one, such as a fake transport for #13's
  handshake and reconnect, or a fake clock for #15.
- Every shell module and the SDK follow the same convention.
- The library builds on the pinned GHC 9.10.3 and has had a release in the last
  24 months.

Nine candidates meet all three. They differ in what a fake costs to write:

- **Records of `IO` functions**, using only `base`. A fake is another record
  value. `rio` packages the same pattern inside a `ReaderT` environment.
- **`mtl`-style classes**, using `mtl` or `capability`. Each fake needs a
  `newtype` and an instance.
- **IO-based effect libraries**: `effectful` and `bluefin`. An `effectful` fake
  is an interpreter function, and a `bluefin` fake is a handle value.
- **Free and higher-order effect libraries**: `polysemy`, `fused-effects`, and
  `heftia-effects`. A `polysemy` or `heftia-effects` fake is an interpreter
  function. A `fused-effects` fake is a carrier `newtype` with an `Algebra`
  instance. Code that `heftia-effects` generates needs `AllowAmbiguousTypes`.

The rest fail a requirement:

- `effet`, `extensible-effects`, `freer-simple`, and `simple-effects` don't
  compile on GHC 9.10.3. The newest `freer-simple` release doesn't resolve, and
  the older one the solver picks doesn't compile.
- `cleff` caps `template-haskell` below the version GHC 9.10.3 ships.
- `in-other-words`, `eveff`, and `freer-effects` compile, but their last
  releases were in 2022, 2021, and 2017.

None of the requirements separates the nine, so the decision takes the one
with the fewest dependencies and the least machinery.

## Decision

The Haskell client shell and the Haskell SDK run in plain `IO`. Each effect
that a test needs to replace is a record of `IO` functions, and a function
that uses the effect takes the record as an argument. Neither uses an effect
library, `mtl`-style effect classes, or a `ReaderT` environment.

`Partir.World.*`, `Partir.Agent.*`, and the wire types in
`Partir.Net.Protocol` (#12) stay pure and take no effect records.

## Consequences

- A test fake is an ordinary record value. Tests need no extra library and no
  instances.
- Bot authors write against plain `IO` and records.
- The compiler doesn't track which effects a function performs. A reader learns
  that from the records the function takes.
- A function that needs several effects takes several records. Records that
  travel together get bundled into one record (Introduce Parameter Object) and
  passed whole (Preserve Whole Object), as an argument like any other.
- A later move to `effectful` or `bluefin` maps each record field onto an
  `effectful` effect constructor or a field of a `bluefin` handle.
