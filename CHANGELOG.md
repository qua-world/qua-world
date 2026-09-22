<!--
SPDX-FileCopyrightText: 2020 Alex Brandt

SPDX-License-Identifier: MIT
-->

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
  agents between buffered pose `Sample`s, sampling a fixed `Delay` in the past
  and blending position linearly and orientation by `slerp`. Past the newest
  sample it projects the agent along the velocity the last two samples imply,
  as far as a `Horizon`, then holds. `prune` bounds a history by dropping the
  samples the render clock has passed.
* `Partir.Asset`: a renderer-ready mesh naming no source format, filled by
  `Partir.Asset.GLTF` from binary glTF 2.0 (`.glb`), so content authored in
  Blockbench or any glTF-emitting tool loads. A malformed document comes back
  as a typed `GltfLoadError`.
* `Partir.Asset.OBJ`: fills the same mesh from a Wavefront OBJ file's
  positions, normals, and polygon faces, split into triangles. Texture
  coordinates and `.mtl` materials go unread. A malformed file comes back as
  a typed `ObjLoadError`.
* `Partir.Asset.Sprite`: a sprite sheet and the frames cut from it, naming no
  source format, filled by `Partir.Asset.Sprite.PNG` from a PNG and the cell
  size its frames sit on, so pixel art authored in Pixelorama or any
  PNG-emitting tool loads. A malformed image comes back as a typed
  `PngLoadError`.
* `Partir.Asset.Animation`: a sprite sheet read as a timed sequence, filled by
  `Partir.Asset.Animation.PNG` from a directory of PNG frames and the rate they
  play at, so frame-by-frame animation authored in Pencil2D or any tool
  exporting an image sequence loads. The frames arrive laid into one sheet, in
  the order their names sort, and `stepAt` says which of them a clock has
  reached. A frame that won't decode comes back as a typed `SequenceLoadError`
  naming it.
* `Partir.Asset.Tilemap`: a tile grid and the entities placed on it, naming no
  editor, filled by `Partir.Asset.Tilemap.Tiled` from Tiled's JSON map export
  (`.tmj`) and by `Partir.Asset.Tilemap.LDtk` from an LDtk project (`.ldtk`),
  so levels authored in either editor load. Coordinates arrive in tile units
  whatever the source art's pixel grid, and `toMesh` lays the cells out in the
  XZ plane as geometry the renderer already draws. A malformed document comes
  back as a typed error.
* Pure `Partir.World.*` domain layer: `Types` (agent/entity/tick identifiers,
  `linear`-backed `Vec3`/`Quat` aliases, and the shared rigid-body `Pose`),
  `Event` (agent-produced world changes), and `Scene` (the shared state and its
  `apply` fold).
* The client renders `examples/avatar.glb` in front of the camera, standing on
  the tiles of `examples/level.ldtk`, lit by the assets' own normals, in an
  OpenGL 3.3 core-profile context.
* The client draws the first frame of `examples/sprites.png` as an icon in the
  window's top-left corner, over the scene and blended against it.
* The client plays `examples/walk/` as a second icon beside that one, looping
  on a timer rather than waiting on input.
* GLUT-based GUI client that opens a "Qua World" window.
* `observe` subcommand to become an observer in qua.world.
* Escape key quits the client.
* GLUT keyboard input reaches the client as `Partir.Agent.Input.Intent`s:
  escape becomes `Quit`, `WASD` become `Move`. Only `Quit` acts; the rest are
  traced.
