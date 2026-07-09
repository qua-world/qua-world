# Content-authoring tools

The project's baseline of open-source tools for producing content —
avatars, world tiles, textures, sprites, dialogue, and audio. Authoring
against this baseline keeps assets in formats the client is built to
consume, so contributors don't each pick a different tool and submit
files the loaders can't read.

## Loader status

The client is currently a GLUT skeleton that clears the screen; **no
asset loader is wired in yet**. Every format below is consumed by a
loader that is planned or unfiled, not built. Author assets against
these formats now — they load once the corresponding loader lands.

- **Planned** — a loader is tracked by a linked issue.
- **Unfiled** — no loader and no tracking issue exists; a loader issue
  must be filed before this content type renders.

## Tools

| Content type | Tool | Produces | License | Loader |
| --- | --- | --- | --- | --- |
| 3D modelling | [Blockbench] | glTF 2.0 (`.glb`/`.gltf`), OBJ | GPL-3.0 | Planned — [#24] |
| Procedural textures | [Material Maker] | PBR map sets (base colour, normal, roughness, metallic, AO) as PNG | MIT | Planned — [#24] |
| Pixel art / sprites | [Pixelorama] | PNG sprites and spritesheets, GIF/APNG | MIT | Unfiled |
| 2D frame animation | [Pencil2D] | PNG frame sequences, video | GPL-2.0 | Unfiled |
| Level / tilemap editing | [Tiled] | TMX/TSX (XML) or JSON tilemaps | GPL-2.0 | Unfiled |
| Level / tilemap editing | [LDtk] | `.ldtk` (JSON), Super Simple Export (PNG + JSON) | MIT | Unfiled |
| Dialogue | [Yarn Spinner] | `.yarn` branching dialogue scripts | MIT | Planned — [#25] |
| Audio editing | [Audacity] | WAV, FLAC, OGG (and MP3) | GPL-3.0 | Unfiled |

### 3D modelling — Blockbench

Low-poly modelling and texturing. Exports glTF 2.0 and OBJ, the standard
open exchange formats for game meshes. glTF is the target for avatars
and world props; the [`Partir.Asset.GLTF`][#24] loader parses glTF 2.0
into renderer-ready meshes.

### Procedural textures — Material Maker

Node-based authoring of tiling PBR materials, exported as PNG map sets
(base colour, normal, roughness, metallic, ambient occlusion). Materials
are referenced from glTF, so they enter the client through the same
[glTF loader][#24] as the meshes they dress.

### Pixel art / sprites — Pixelorama

Sprite and spritesheet authoring, exporting PNG (with GIF and animated
PNG for previews). No sprite/texture loader is filed yet; author sprites
as PNG spritesheets so they're ready when one is.

### 2D frame animation — Pencil2D

Hand-drawn frame-by-frame animation, exporting PNG frame sequences (or
video for reference). No animation loader is filed yet.

### Level / tilemap editing — Tiled

Broad, stable, engine-agnostic tilemap editor. Writes TMX/TSX (XML) or
JSON. Choose Tiled when the map is a plain grid of tiles. No tilemap
loader is filed yet.

### Level / tilemap editing — LDtk

Entity-driven, opinionated level editor. Writes `.ldtk` (JSON) plus a
Super Simple Export (flat PNG layers and JSON) for engines without a
dedicated importer. Choose LDtk when levels are built from entities and
enums rather than raw tile grids. No tilemap loader is filed yet.

### Dialogue — Yarn Spinner

Branching-narrative authoring: writers own `.yarn` scripts on a surface
separate from the runtime. The [`partir-yarn`][#25] runtime port parses
`.yarn` and drives conversations from it.

### Audio editing — Audacity

Recording and cleanup of sound effects and music, exporting WAV, FLAC,
or OGG. No audio loader is filed yet.

[Blockbench]: https://www.blockbench.net/
[Material Maker]: https://www.materialmaker.org/
[Pixelorama]: https://orama-interactive.itch.io/pixelorama
[Pencil2D]: https://www.pencil2d.org/
[Tiled]: https://www.mapeditor.org/
[LDtk]: https://ldtk.io/
[Yarn Spinner]: https://www.yarnspinner.dev/
[Audacity]: https://www.audacityteam.org/
[#24]: https://github.com/qua-world/partir.qua.world/issues/24
[#25]: https://github.com/qua-world/partir.qua.world/issues/25
