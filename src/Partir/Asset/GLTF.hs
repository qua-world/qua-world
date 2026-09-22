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

Each mesh is placed by the nodes that reference it: a node's translation,
rotation, and scale compose down the hierarchy and are baked into positions
and normals. A mesh no node references is not drawn, and one referenced twice
is drawn twice.

@gltf-loader@ drops a node's @matrix@ and the document's scene list, so a
@matrix@ node contributes no transform and every scene's nodes are drawn
(#126).
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
import Data.Foldable (toList)
import Data.Maybe (fromMaybe)
import qualified Data.Set as Set
import qualified Data.Vector as Vector
import Linear (
  M33,
  M44,
  Quaternion (..),
  V3 (..),
  V4 (..),
  fromQuaternion,
  identity,
  inv33,
  mkTransformationMat,
  normalize,
  normalizePoint,
  point,
  scaled,
  transpose,
  (!*),
  (!*!),
 )

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
fromGltf gltf = Asset.Mesh (concatMap (placeNode identity) roots)
 where
  nodes = GLTF.gltfNodes gltf
  children = Set.fromList (concatMap (toList . GLTF.nodeChildren) nodes)
  roots = [i | i <- [0 .. Vector.length nodes - 1], i `Set.notMember` children]

  placeNode :: M44 Float -> Int -> [Asset.Primitive]
  placeNode parent i = case nodes Vector.!? i of
    Nothing -> []
    Just node ->
      let world = parent !*! localTransform node
          mesh = GLTF.nodeMeshId node >>= (GLTF.gltfMeshes gltf Vector.!?)
       in maybe [] (map (transformPrimitive world . fromPrimitive) . toList . GLTF.meshPrimitives) mesh
            ++ concatMap (placeNode world) (GLTF.nodeChildren node)

-- | A node's translation, rotation, and scale as one matrix, applied scale first.
localTransform :: GLTF.Node -> M44 Float
localTransform node = mkTransformationMat (rotation !*! scaled scale) offset
 where
  offset = fromMaybe 0 (GLTF.nodeTranslation node)
  scale = fromMaybe 1 (GLTF.nodeScale node)
  -- glTF stores a quaternion as (x, y, z, w); linear puts the scalar first.
  rotation = maybe identity (\(V4 x y z w) -> fromQuaternion (Quaternion w (V3 x y z))) (GLTF.nodeRotation node)

{- | Bake a world transform into a primitive. Normals take the inverse transpose
so they stay perpendicular to their surface under non-uniform scale.
-}
transformPrimitive :: M44 Float -> Asset.Primitive -> Asset.Primitive
transformPrimitive world p =
  p
    { Asset.primitivePositions = Vector.map (normalizePoint . (world !*) . point) (Asset.primitivePositions p)
    , Asset.primitiveNormals = Vector.map (normalize . (normalMatrix !*)) (Asset.primitiveNormals p)
    }
 where
  normalMatrix :: M33 Float
  normalMatrix = transpose (inv33 (fmap dropW (dropW world)))
  dropW (V4 x y z _) = V3 x y z

fromPrimitive :: GLTF.MeshPrimitive -> Asset.Primitive
fromPrimitive p =
  Asset.Primitive
    { Asset.primitivePositions = GLTF.meshPrimitivePositions p
    , Asset.primitiveIndices = Vector.map fromIntegral (GLTF.meshPrimitiveIndices p)
    , Asset.primitiveNormals = GLTF.meshPrimitiveNormals p
    , Asset.primitiveMaterial = GLTF.meshPrimitiveMaterial p
    }
