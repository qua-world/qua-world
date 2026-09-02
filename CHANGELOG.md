# Revision history for partir-qua-world

<!-- The Keep a Changelog preamble, quoted verbatim. -->
<!-- vale off -->

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to the [Haskell Package Versioning Policy](https://pvp.haskell.org/).

<!-- vale on -->

Until the first tagged release, entries collect under a single `### Added`
bucket. Later `[Unreleased]` sections split by change type.

## [Unreleased]

### Added

* `Partir.Agent.*`: the abstraction every participant implements, comprising
  `Input` (the `Intent` vocabulary an agent emits), `Class` (the pure `step`
  over what the agent perceives), and `Null` (an agent that emits nothing).
* `Partir.Sim.Interpolate`: pure snapshot interpolation that smooths remote
  agents between buffered pose `Sample`s, sampling a fixed delay in the past and
  blending position linearly and orientation by `slerp`.
* Pure `Partir.World.*` domain layer: `Types` (agent/entity/tick identifiers,
  `linear`-backed `Vec3`/`Quat` aliases, and the shared rigid-body `Pose`),
  `Event` (agent-produced world changes), and `Scene` (the shared state and its
  `apply` fold).
* GLUT-based GUI client that opens a "Qua World" window.
* `observe` subcommand to become an observer in qua.world.
* Escape key quits the client.
