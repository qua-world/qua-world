-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Partir.Asset.GLTFSpec (
  test_loadAsset,
  test_loadAssetBytes,
)
where

import qualified Data.ByteString.Char8 as ByteString
import qualified Data.Vector as Vector
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertFailure, testCase, (@?=))

import Partir.Asset (
  Mesh (..),
  Primitive (..),
  indexCount,
  vertexCount,
 )
import Partir.Asset.GLTF (GltfLoadError, loadAsset, loadAssetBytes)
import Paths_partir_qua_world (getDataFileName)

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
    ]

-- | Load the example cube, failing the test case with the decode error.
loadCube :: IO Mesh
loadCube =
  getDataFileName "examples/avatar.glb"
    >>= loadAsset
    >>= either (assertFailure . show) pure

onlyPrimitive :: Mesh -> IO Primitive
onlyPrimitive mesh =
  case meshPrimitives mesh of
    [prim] -> pure prim
    prims -> assertFailure ("expected one primitive, got " ++ show (length prims))
