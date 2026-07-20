# Example assets

## `avatar.glb`

A placeholder unit cube in binary glTF 2.0, loaded by `partir-glut` on startup
and by the `Partir.Asset.GLTF` loader tests. It stands in for real content
authored in [Blockbench](https://www.blockbench.net/) until such an avatar
exists — glTF is what Blockbench and most low-poly modelling tools export.

The geometry is 24 vertices (four per face, so each face carries its own
normal), 36 triangle indices, and one material. Replace it with a real
Blockbench glTF export and the loader and renderer pick it up unchanged.
