# Content-authoring tools

The project's baseline of open-source tools for producing content.
Authoring against it keeps assets in formats the client is built to
consume, so contributors don't each pick a different tool.

The client is a GLUT skeleton that clears the screen; **no asset loader
is wired in yet**. Author against the listed formats now — each loads
once its loader lands. Loader status:

- **Planned** — a loader is tracked by a linked issue.
- **Unfiled** — no loader and no tracking issue exists; file one before
  the content type renders.

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

## Notes

- **Blockbench and Material Maker** both target glTF: meshes and the PBR
  materials they reference load through [`Partir.Asset.GLTF`][#24].
- **Tiled vs LDtk**: Tiled for plain tile grids, LDtk for entity- and
  enum-driven levels.
- **Yarn Spinner** scripts run on the [`partir-yarn`][#25] runtime.
- **Unfiled** types — sprites, animation, tilemaps, audio — have no
  loader; author against the listed formats and file a loader issue
  before they render.

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
