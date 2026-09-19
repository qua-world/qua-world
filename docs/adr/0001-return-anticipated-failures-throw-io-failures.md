<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# 1. Return anticipated failures, throw I/O failures

## Status

Proposed

## Context

Every impure edge of the client can fail. The asset loaders read files that may
be absent or malformed (#24, #69, and #52 through #55). The wire transport (#14)
and the world-server will meet the same question. Haskell offers several shapes
for reporting a failure, and choosing one per module leaves a caller learning a
new convention at each boundary.

The glTF loader in #24 raised the question first and settled on a shape during
review, but the reasoning stayed in that pull request. The sibling loaders
would each derive it again from nothing. #76 asked for the convention to be
ratified here before more code sets it by precedent.

Three shapes were weighed.

Throwing a typed exception for every failure gives one mechanism to learn. A
caller that wants to handle a malformed file has to catch. The type signature
never asks for that, so the missing handler surfaces at run time rather than at
compile time.

Returning `Either` for every failure puts each one in the type. Applied to a
genuine I/O failure it means wrapping operations that already throw `IOError`.
The caller gains a branch for an outcome it was never going to recover from.

Threading `ExceptT` over `IO` moves the error channel into the monad stack.
`IO` already carries an exception channel, so this adds a second one that
covers only the failures the code remembered to route through it, leaving two
mechanisms live at once.

A survey of 2025-26 community guidance, recorded in #76, reached the same
split. An error carried as a bare `String` or `Text` is the one categorically
wrong choice. A parse failure belongs in a return value, and an I/O failure
belongs in an exception.

## Decision

We will split error reporting on whether the failure is anticipated.

A failure a module reports carries an error type of its own, named for the
module, such as `GltfLoadError`. We won't report a failure as `String`, `Text`,
or `userError`.

An anticipated failure, one the module reaches by inspecting input it was
handed, is returned. Decoding, parsing, and validation land here, and the
signature says so: `loadAsset :: FilePath -> IO (Either GltfLoadError Mesh)`.

A genuine I/O failure stays an exception. A missing file, an unreadable handle,
or a closed socket already throws `IOError` from the operation that met it, and
we won't catch one to re-report it as a `Left`.

Each error type gets an `Exception` instance, so a caller that wants an
anticipated failure to be fatal can `throwIO` it. The GLUT client does that
when an asset fails to load at startup.

We'll reach for `safe-exceptions` at a catch site, where the distinction
between synchronous and asynchronous exceptions decides whether catching is
correct. Code that only throws needs nothing beyond `Control.Exception`.

We won't thread `ExceptT` or `EitherT` over `IO`.

## Consequences

A caller reads a signature and knows which failures it has to handle. The
compiler asks about the anticipated ones and stays quiet about the rest, which
is the line this record draws.

Two mechanisms stay in play, and the boundary between them is a judgment call.
Input the module inspects is anticipated. An operation the runtime refuses
isn't. Cases that sit near the line get decided in review, and a decision that
generalizes belongs back in this record.

Every module at an impure edge writes an error type before it writes its first
failure path. For a loader that reports one kind of failure this looks like
overhead, and it's what keeps a caller from matching on rendered text.

`safe-exceptions` isn't a dependency yet, because nothing catches yet. Version
0.1.7.4 resolves and builds against the GHC series `tested-with` pins, so the
first catch site can add it without reopening this decision.

The first application is the glTF loader written in #64 against #24. That pull
request closed without merging, so the convention is ratified ahead of the code
rather than read out of it, which is what #76 asked for. Whatever revives that
work conforms to this record.

This record assumes the impure layers are bare `IO`. The effect-system question
in #43 covers that assumption, and a decision to adopt an effect system would
supersede the mechanics here even where it keeps the anticipated-versus-genuine
split.
