# Revision history for partir-qua-world

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to the [Haskell Package Versioning Policy](https://pvp.haskell.org/).
Until the first release is tagged, entries collect under a single `### Added`
bucket; later `[Unreleased]` sections split by change type.

## [Unreleased]

### Added

* `Partir.Sim.Interpolate`: pure snapshot interpolation that smooths remote
  agents between buffered `Snapshot`s, sampling a fixed delay in the past and
  blending position linearly and orientation by `slerp`.
* Pure `Partir.World.*` domain layer: `Types` (agent/entity/tick identifiers
  and `linear`-backed `Vec3`/`Quat` aliases), `Event` (agent-produced world
  changes), and `Scene` (the shared state and its `apply` fold).
* GLUT-based GUI client that opens a "Qua World" window.
* `observe` subcommand to become an observer in qua.world.
* Escape key quits the client.
