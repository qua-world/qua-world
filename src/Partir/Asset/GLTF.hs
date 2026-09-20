-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Asset.GLTF
Description : Load glTF 2.0 / GLB documents into a renderer-ready 'Asset.Mesh'

Reads binary glTF (@.glb@) and flattens it into the format-neutral
'Asset.Mesh' the renderer consumes. The @gltf-loader@ dependency and its
@rio@ prelude are confined to this module: none of it appears in the returned
type.

Node transforms are not applied, so a document whose parts are placed by node
draws them all at the origin (#67).
-}
module Partir.Asset.GLTF (
  GltfLoadError (..),
  loadAsset,
  loadAssetBytes,
)
where

import Control.Exception (Exception)
import Data.Bifunctor (bimap)
import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import qualified Data.Vector as Vector

import qualified Text.GLTF.Loader as GLTF

import qualified Partir.Asset as Asset

{- | A glTF document that could not be decoded, wrapping the underlying
@gltf-loader@ diagnostic. The 'Exception' instance lets a caller 'throwIO' it
where a decode failure should be fatal, as the client does at startup.
-}
newtype GltfLoadError = GltfLoadError GLTF.Errors
  deriving Show

instance Exception GltfLoadError

{- | Load a binary glTF file into a renderer-ready mesh. A malformed document
is anticipated, so it comes back as a 'Left'; a missing or unreadable file is
an I\/O failure and surfaces as the 'IOError' thrown by reading it.
-}
loadAsset :: FilePath -> IO (Either GltfLoadError Asset.Mesh)
loadAsset path = ByteString.readFile path >>= loadAssetBytes

{- | Decode in-memory GLB bytes under the same contract as 'loadAsset', for
content that arrives from somewhere other than a file.
-}
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
