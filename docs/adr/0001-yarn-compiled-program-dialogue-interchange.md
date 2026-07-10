# 1. Adopt Yarn Spinner's compiled Program as the dialogue interchange

## Status

Proposed

## Context

qua.world wants writers to author branching NPC dialogue in standard tooling and
have any client drive conversations from it (#25). Two constraints shape the
choice:

- **NPCs are clients.** `Partir.Agent.*` (#11) already treats every participant
  — player, bot, NPC — uniformly as an event-producing agent, with `Speak Text`
  in the `Intent` vocabulary. A dialogue runtime is therefore an agent's *brain*,
  not a simulation or server concern.
- **Authors pick their language.** The value of "NPCs are clients" is only
  realised if a contributor can write an NPC in the language of their choice.

Yarn Spinner is deliberately built so that "the writer's tool and the
programmer's runtime are separate surfaces." Its reference compiler (C#, ANTLR
grammar) compiles a `.yarn` source into a `Program` protobuf, which a small
runtime VM executes against host hooks (variable storage, line handler, command
handler, option selection). The `Program` protobuf is already language-portable.

No Haskell port of the runtime exists. Three ways to close that gap were weighed:

1. **A Haskell parser + interpreter from source.** Reimplements the Yarn grammar
   in Haskell. Serves only Haskell NPC-clients; contributes nothing to
   multi-language authoring, since every other language would have to reimplement
   the grammar too.
2. **Adopt the compiled `Program` as the interchange.** Compile `.yarn` once with
   the reference compiler; every language runs the same `Program` through a small
   VM. The portable artifact is the compiled program, not any one language's
   parser.
3. **A codegen toolchain** that generates a whole NPC codebase from a script.
   Weakly motivated: a `.yarn` file describes *only dialogue*, not movement,
   perception, or decision-making, so it cannot be the sole input to "generate my
   NPC."

The wire protocol between client and server is a separate seam, owned by
`Partir.Net.Protocol` (#12) and the surrounding `Partir.Net.*` stack — it needs
multi-language bindings whether or not NPCs speak Yarn, and must not be coupled
to the dialogue runtime.

## Decision

We will adopt Yarn Spinner's compiled `Program` protobuf as qua.world's portable
dialogue interchange.

- `.yarn` sources are compiled to `Program` by wrapping (or vendoring) the
  reference compiler, kept as a build-time toolchain step.
- qua.world provides a **Haskell VM** that executes a `Program` against host
  hooks, and binds those hooks to `Partir.Agent.*`: the line handler emits a
  `Speak` intent, command directives map to other intents, variable storage is
  agent-local, and option selection round-trips through the agent.
- Any additional language delivers NPC dialogue by supplying its own VM over the
  same `Program`; the grammar is never reimplemented per language.
- "Generate an NPC from a script" is out of scope for the dialogue runtime.
  Scaffolding an NPC-client project — protocol bindings plus a dialogue-driven
  brain stub — is a separate, deferred concern, and covers only the
  conversational surface, not the whole NPC.

## Consequences

Cross-language NPC dialogue becomes tractable without reimplementing the Yarn
grammar in each language, and writers keep the standard Yarn authoring tools. The
Haskell VM (#25) is a smaller deliverable than a from-scratch parser, and it
composes cleanly with the existing agent model.

The costs: a build-time dependency on the C# reference compiler enters the
toolchain (#25's blocker), which complicates CI and contributor setup; the
compiled-`Program` format couples us to the Yarn Spinner release that produced
it, so the Haskell VM must track the opcode set the compiler emits; and
delivering an NPC that actually speaks in-world stays blocked on the `Partir.Net`
protocol (#12) and the agent binding, not just the VM.

Neutrally, this decision governs dialogue only. The uniform-agent / NPCs-as-
clients model it rests on is `Partir.Agent.*` (#11) and the client/server ADR
(#26); this record does not re-decide it.
