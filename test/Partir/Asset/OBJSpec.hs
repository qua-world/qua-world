-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Partir.Asset.OBJSpec (
  test_loadAsset,
)
where

import qualified Data.Vector as Vector
import Linear.V3 (V3 (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertFailure, testCase, (@?=))

import Partir.Asset (
  Mesh (..),
  Primitive (..),
  indexCount,
  vertexCount,
 )
import Partir.Asset.OBJ (ObjLoadError (..), loadAsset)
import Paths_partir_qua_world (getDataFileName)

test_loadAsset :: TestTree
test_loadAsset =
  testGroup
    "loadAsset"
    [ testCase "splits a quad into two triangles sharing its diagonal" $ do
        prim <- loadText (unlines (square ++ ["f 1 2 3 4"])) >>= onlyPrimitive
        primitiveIndices prim @?= Vector.fromList [0, 1, 2, 0, 2, 3]
        primitivePositions prim
          @?= Vector.fromList [V3 0 0 0, V3 1 0 0, V3 1 1 0, V3 0 1 0]
    , testCase "gives a shared position a vertex per normal it meets" $ do
        prim <-
          loadText (unlines (square ++ ["vn 0 0 1", "vn 0 0 -1", "f 1//1 2//1 3//1", "f 1//2 3//2 4//2"]))
            >>= onlyPrimitive
        Vector.length (primitivePositions prim) @?= 6
        primitiveNormals prim @?= Vector.fromList (replicate 3 (V3 0 0 1) ++ replicate 3 (V3 0 0 (-1)))
    , testCase "reuses a vertex whose position and normal recur" $ do
        prim <- loadText (unlines (square ++ ["vn 0 0 1", "f 1//1 2//1 3//1", "f 1//1 3//1 4//1"])) >>= onlyPrimitive
        Vector.length (primitivePositions prim) @?= 4
        Vector.length (primitiveNormals prim) @?= 4
    , -- A primitive's normals are per vertex, so a partial set would leave
      -- some vertices reading past the end of the attribute.
      testCase "drops the normals when any corner lacks one" $ do
        prim <- loadText (unlines (square ++ ["vn 0 0 1", "f 1//1 2//1 3//1", "f 1 3 4"])) >>= onlyPrimitive
        primitiveNormals prim @?= Vector.empty
    , testCase "reports a face pointing past the declared positions" $ do
        result <- loadText (unlines (square ++ ["f 1 2 5"]))
        result @?= Left (ObjDanglingIndex 5)
    , testCase "reports a face pointing past the declared normals" $ do
        result <- loadText (unlines (square ++ ["vn 0 0 1", "f 1//1 2//2 3//1"]))
        result @?= Left (ObjDanglingIndex 2)
    , testCase "reports text that does not tokenize" $ do
        result <- loadText "v 1 2\n"
        case result of
          Left (ObjSyntaxError _) -> pure ()
          other -> assertFailure ("expected a syntax error, got " ++ show other)
    , testCase "loads a file without faces as an empty mesh" $ do
        result <- loadText (unlines square)
        result @?= Right (Mesh [])
    , {- @examples/pyramid.obj@ has four triangular sides and a square base,
      each with its own normal: 4 * 3 + 4 = 16 vertices, and 4 * 3 + 2 * 3 = 18
      indices. These expectations track that file.
      -}
      testCase "loads the example pyramid's geometry counts" $ do
        mesh <-
          getDataFileName "examples/pyramid.obj"
            >>= loadAsset
            >>= either (assertFailure . show) pure
        vertexCount mesh @?= 16
        indexCount mesh @?= 18
    ]

-- | The corners of a unit square in the @xy@ plane, counter-clockwise.
square :: [String]
square = ["v 0 0 0", "v 1 0 0", "v 1 1 0", "v 0 1 0"]

-- | Load OBJ source by writing it where 'loadAsset' can read it.
loadText :: String -> IO (Either ObjLoadError Mesh)
loadText source =
  withSystemTempDirectory "partir-obj" $ \dir -> do
    let path = dir </> "mesh.obj"
    writeFile path source
    loadAsset path

onlyPrimitive :: Either ObjLoadError Mesh -> IO Primitive
onlyPrimitive (Left err) = assertFailure (show err)
onlyPrimitive (Right mesh) =
  case meshPrimitives mesh of
    [prim] -> pure prim
    prims -> assertFailure ("expected one primitive, got " ++ show (length prims))
