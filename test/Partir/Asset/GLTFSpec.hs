-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Partir.Asset.GLTFSpec (
  test_loadAsset,
  test_loadAssetBytes,
)
where

import Data.ByteString (ByteString)
import qualified Data.ByteString.Builder as Builder
import qualified Data.ByteString.Char8 as ByteString
import qualified Data.ByteString.Lazy as Lazy
import qualified Data.Vector as Vector
import Data.Word (Word32)
import Linear (V3 (..), distance)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertFailure, testCase, (@?=))

import Partir.Asset (
  Mesh (..),
  Primitive (..),
  indexCount,
  vertexCount,
 )
import Partir.Asset.Bundled (bundled)
import Partir.Asset.GLTF (GltfLoadError, loadAsset, loadAssetBytes)

{- | @examples/avatar.glb@ is a placeholder unit cube standing in for real
Blockbench content: 6 faces * 4 corners = 24 vertices, 6 faces * 2 triangles *
3 corners = 36 indices, one material. These expectations track that file.
-}
test_loadAsset :: TestTree
test_loadAsset =
  testGroup
    "loadAsset"
    [ testCase "loads the example cube's geometry counts" $ do
        mesh <- loadCube
        vertexCount mesh @?= 24
        indexCount mesh @?= 36
    , testCase "flattens to a single primitive carrying its normals" $ do
        mesh <- loadCube
        prim <- onlyPrimitive mesh
        Vector.length (primitiveNormals prim) @?= 24
    , testCase "preserves the primitive's material binding" $ do
        mesh <- loadCube
        prim <- onlyPrimitive mesh
        primitiveMaterial prim @?= Just 0
    , -- glTF stores indices at whatever width the document chose, 16-bit for
      -- this cube, and the loader widens them to Word32. A mangled conversion
      -- shows up as an index pointing past the vertices it selects from.
      testCase "widens every index to one that selects a vertex" $ do
        mesh <- loadCube
        prim <- onlyPrimitive mesh
        let vertices = Vector.length (primitivePositions prim)
        assertBool
          "an index falls outside the primitive's positions"
          (all (\i -> fromIntegral i < vertices) (primitiveIndices prim))
    ]

test_loadAssetBytes :: TestTree
test_loadAssetBytes =
  testGroup
    "loadAssetBytes"
    [ testCase "returns the decode failure for non-GLB bytes" $ do
        result <- loadAssetBytes (ByteString.pack "not a glb")
        case result :: Either GltfLoadError Mesh of
          Left _ -> pure ()
          Right _ -> assertFailure "expected a decode failure"
    , testCase "places positions by the composed node transforms" $ do
        prim <- loadPlaced
        assertNear
          (Vector.toList (primitivePositions prim))
          [V3 1 4 3, V3 0 2 3, V3 1 2 4]
    , testCase "turns normals with the node rotation, perpendicular under scale" $ do
        prim <- loadPlaced
        assertNear
          (Vector.toList (primitiveNormals prim))
          [V3 0 1 0, V3 0 0 1, V3 (-2) 1 0 / sqrt 5]
    ]

-- | Load the one primitive 'placedGlb' places, failing the test case otherwise.
loadPlaced :: IO Primitive
loadPlaced = loadAssetBytes placedGlb >>= either (assertFailure . show) onlyPrimitive

{- | A three-vertex mesh under two nodes. The parent translates by (1, 2, 3)
and turns a quarter about Z. Its child scales X by 2 and holds the mesh. The
child comes first in @nodes@, so only a walk from the parent places it. The
diagonal normal is the one non-uniform scale bends, which separates the inverse
transpose from the plain matrix.
-}
placedGlb :: ByteString
placedGlb = glb json (floats positions <> floats normals)
 where
  positions = [V3 1 0 0, V3 0 1 0, V3 0 0 1]
  normals = [V3 1 0 0, V3 0 0 1, V3 1 1 0 / sqrt 2]
  floats = foldMap (foldMap Builder.floatLE)
  json =
    concat
      [ "{\"asset\":{\"version\":\"2.0\"},"
      , "\"buffers\":[{\"byteLength\":72}],"
      , "\"bufferViews\":[{\"buffer\":0,\"byteOffset\":0,\"byteLength\":36},"
      , "{\"buffer\":0,\"byteOffset\":36,\"byteLength\":36}],"
      , "\"accessors\":[{\"bufferView\":0,\"componentType\":5126,\"count\":3,\"type\":\"VEC3\"},"
      , "{\"bufferView\":1,\"componentType\":5126,\"count\":3,\"type\":\"VEC3\"}],"
      , "\"meshes\":[{\"primitives\":[{\"attributes\":{\"POSITION\":0,\"NORMAL\":1}}]}],"
      , "\"nodes\":[{\"mesh\":0,\"scale\":[2,1,1]},"
      , "{\"children\":[0],\"translation\":[1,2,3],\"rotation\":[0,0,0.70710677,0.70710677]}],"
      , "\"scenes\":[{\"nodes\":[1]}],\"scene\":0}"
      ]

{- | Frame a JSON document and its binary buffer as GLB: a 12-byte header, then
each chunk as length, type tag, and payload padded to four bytes.
-}
glb :: String -> Builder.Builder -> ByteString
glb json bin =
  Lazy.toStrict . Builder.toLazyByteString $
    word32 0x46546C67
      <> word32 2
      <> word32 (12 + len jsonChunk + len binChunk)
      <> Builder.lazyByteString jsonChunk
      <> Builder.lazyByteString binChunk
 where
  jsonChunk = chunk 0x4E4F534A ' ' (Builder.string7 json)
  binChunk = chunk 0x004E4942 '\0' bin
  chunk tag pad body =
    let bytes = Builder.toLazyByteString body
        padding = Lazy.replicate ((-Lazy.length bytes) `mod` 4) (fromIntegral (fromEnum pad))
        payload = bytes <> padding
     in Builder.toLazyByteString (word32 (len payload) <> word32 tag <> Builder.lazyByteString payload)
  word32 = Builder.word32LE
  len :: Lazy.ByteString -> Word32
  len = fromIntegral . Lazy.length

assertNear :: [V3 Float] -> [V3 Float] -> IO ()
assertNear actual expected =
  assertBool
    ("expected " ++ show expected ++ ", got " ++ show actual)
    (length actual == length expected && and (zipWith (\a e -> distance a e < 1e-5) actual expected))

-- | Load the example cube, failing the test case with the decode error.
loadCube :: IO Mesh
loadCube = bundled "examples/avatar.glb" loadAsset

onlyPrimitive :: Mesh -> IO Primitive
onlyPrimitive mesh =
  case meshPrimitives mesh of
    [prim] -> pure prim
    prims -> assertFailure ("expected one primitive, got " ++ show (length prims))
