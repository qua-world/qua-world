{-|
Module      : Partir.Asset.GLTF
Description : Load glTF 2.0 / GLB documents into a renderer-ready 'Mesh'
Copyright   : (c) Alex Brandt, 2026
License     : MIT

Reads binary glTF (@.glb@) — the de facto open exchange format emitted by
Blockbench, Material Maker, and most modelling tools — and flattens it into the
format-neutral 'Asset.Mesh' the renderer consumes. The @gltf-loader@ dependency
(and its @rio@ prelude) is confined to this module: nothing of it appears in the
returned type.
-}
module Partir.Asset.GLTF
  ( loadAsset
  , loadAssetBytes
  )
where

import Control.Monad ((>=>))
import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import qualified Data.Vector as Vector

import qualified Partir.Asset as Asset

import qualified Text.GLTF.Loader as GLTF

-- | Load a binary glTF file into a renderer-ready mesh. Throws an 'IOError'
-- carrying the loader's diagnostic if the bytes are not valid GLB.
loadAsset :: FilePath -> IO Asset.Mesh
loadAsset = ByteString.readFile >=> loadAssetBytes

-- | Decode in-memory GLB bytes into a mesh. Useful for content streamed from
-- the server or embedded in tests, and the shared core of 'loadAsset'.
loadAssetBytes :: ByteString -> IO Asset.Mesh
loadAssetBytes bytes = do
  result <- GLTF.fromBinaryByteString bytes
  case result of
    Left err -> ioError (userError ("glTF load failed: " ++ show err))
    Right glb -> pure (fromGltf (GLTF.unGltf glb))

fromGltf :: GLTF.Gltf -> Asset.Mesh
fromGltf =
  Asset.Mesh
    . concatMap (map fromPrimitive . Vector.toList . GLTF.meshPrimitives)
    . Vector.toList
    . GLTF.gltfMeshes

fromPrimitive :: GLTF.MeshPrimitive -> Asset.Primitive
fromPrimitive p =
  Asset.Primitive
    { Asset.primitivePositions = GLTF.meshPrimitivePositions p
    , Asset.primitiveIndices = Vector.map fromIntegral (GLTF.meshPrimitiveIndices p)
    , Asset.primitiveNormals = GLTF.meshPrimitiveNormals p
    , Asset.primitiveMaterial = GLTF.meshPrimitiveMaterial p
    }
