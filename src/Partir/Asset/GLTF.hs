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
  ( GltfLoadError (..)
  , loadAsset
  , loadAssetBytes
  )
where

import Control.Exception (Exception)
import Data.Bifunctor (bimap)
import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import qualified Data.Vector as Vector

import qualified Partir.Asset as Asset

import qualified Text.GLTF.Loader as GLTF

-- | A glTF document that could not be decoded, wrapping the underlying
-- @gltf-loader@ diagnostic. Returned in the 'Left' of both loaders; its
-- 'Exception' instance lets a caller 'Control.Exception.throwIO' it when a
-- decode failure should be fatal (e.g. at startup).
newtype GltfLoadError = GltfLoadError GLTF.Errors
  deriving (Show)

instance Exception GltfLoadError

-- | Load a binary glTF file into a renderer-ready mesh. A malformed document is
-- returned as a 'Left' 'GltfLoadError' (a decode failure is anticipated, so it
-- lives in the type); a missing or unreadable file surfaces as the usual
-- 'IOError' thrown by reading it (an I\/O failure, left to exceptions).
loadAsset :: FilePath -> IO (Either GltfLoadError Asset.Mesh)
loadAsset path = ByteString.readFile path >>= loadAssetBytes

-- | Decode in-memory GLB bytes, returning any decode failure in the type so a
-- caller can recover locally — a bad asset need not crash the client. Useful
-- for content streamed from the server, and the shared core of 'loadAsset'.
loadAssetBytes :: ByteString -> IO (Either GltfLoadError Asset.Mesh)
loadAssetBytes bytes =
  bimap GltfLoadError (fromGltf . GLTF.unGltf) <$> GLTF.fromBinaryByteString bytes

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
