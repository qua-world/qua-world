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

The glTF loader in #24 raised the question first, and its answer lived only in
the pull request that made it. The sibling loaders would each derive that answer
again, so the convention is ratified here before more code sets it by
precedent.

Three shapes answer the question. Throwing a typed exception for every failure
gives one mechanism to learn. A caller that wants to handle a malformed file
has to catch. The type signature never asks for that, so the missing handler
surfaces at run time rather than at compile time.

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

We will split error reporting on whether the failure is anticipated. A module
reaches an anticipated failure by inspecting input it was handed; an
unanticipated one is the runtime refusing an operation. Five rules follow.

**A module owns its error type.** It carries a type named for the module, such
as `GltfLoadError`, with an `Exception` instance so a caller that wants the
failure fatal can `throwIO` it. We won't report a failure as `String`, `Text`,
or `userError`.

**An anticipated failure is returned.** Decoding, parsing, and validation land
here, in the `Left` of an `IO (Either ModuleError a)` the signature declares.

**A genuine I/O failure stays an exception.** A missing file, an unreadable
handle, or a closed socket already throws `IOError` from the operation that met
it, and we won't catch one to re-report it as a `Left`.

**`safe-exceptions` belongs at a catch site.** Catching is where the difference
between synchronous and asynchronous exceptions decides whether the catch is
correct. Code that only throws needs nothing beyond `Control.Exception`.

**`ExceptT` and `EitherT` over `IO` stay out.**

## Consequences

A caller reads a signature and knows which failures it has to handle. The
compiler asks about the anticipated ones and stays quiet about the rest.

Two mechanisms stay in play, and the test that picks between them is a judgment
call at the margin. A ruling that generalizes belongs back in this record.

Every module at an impure edge writes an error type before it writes its first
failure path. For a loader that reports one kind of failure this looks like
overhead, and it's what keeps a caller from matching on rendered text.

`safe-exceptions` isn't a dependency, because nothing catches. The first catch
site adds it.

The glTF loader in #64 is the first application: it names `GltfLoadError`, gives
it the `Exception` instance, and turns a decode failure fatal at startup with
`either throwIO pure`.

This record assumes the impure layers are bare `IO`. The effect-system question
in #43 covers that assumption, and a decision to adopt an effect system would
supersede the mechanics here even where it keeps the anticipated-versus-genuine
split.
