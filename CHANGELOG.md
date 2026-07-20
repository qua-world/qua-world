# Revision history for partir-qua-world

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to the [Haskell Package Versioning Policy](https://pvp.haskell.org/).
Until the first release is tagged, entries collect under a single `### Added`
bucket; later `[Unreleased]` sections split by change type.

## [Unreleased]

### Added

* Pure `Partir.World.*` domain layer: `Types` (agent/entity/tick identifiers
  and `linear`-backed `Vec3`/`Quat` aliases), `Event` (agent-produced world
  changes), and `Scene` (the shared state and its `apply` fold).
* GLUT-based GUI client that opens a "Qua World" window.
* `observe` subcommand to become an observer in qua.world.
* Escape key quits the client.
* `Partir.Asset` renderer-ready mesh type and `Partir.Asset.GLTF` loader for
  binary glTF 2.0 (`.glb`), so content authored in Blockbench or any
  glTF-emitting tool can be loaded.
* The GLUT client renders a loaded mesh (`examples/avatar.glb`) in front of the
  camera instead of clearing to an empty window.
