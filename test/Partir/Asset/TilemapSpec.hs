-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Partir.Asset.TilemapSpec (
  test_toMesh,
)
where

import Data.Maybe (isJust)
import qualified Data.Text as Text
import qualified Data.Vector as Vector
import Linear.V3 (V3 (..))
import Test.QuickCheck (Property, Testable, checkCoverage, cover)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (testProperty)

import Partir.Arbitrary ()
import Partir.Asset (
  Mesh (..),
  Primitive (..),
  indexCount,
  vertexCount,
 )
import Partir.Asset.Tilemap (
  TileLayer (..),
  Tilemap (..),
  tileCount,
  toMesh,
 )

test_toMesh :: TestTree
test_toMesh =
  testGroup
    "toMesh"
    [ testProperty "draws a quad for each filled cell and nothing for the rest" $
        \tilemap ->
          overLayerKinds tilemap $
            let mesh = toMesh tilemap
             in vertexCount mesh == 4 * tileCount tilemap
                  && indexCount mesh == 6 * tileCount tilemap
    , -- An offset taken from the cell rather than from the quad still indexes
      -- inside a layer with every cell filled, and runs off the end of one
      -- with gaps.
      testProperty "indexes only the vertices of the primitive it belongs to" $
        \tilemap ->
          overLayerKinds tilemap $
            all selectsOwnVertex (meshPrimitives (toMesh tilemap))
    , testProperty "leaves out a layer that came out empty" $ \tilemap ->
        overLayerKinds tilemap $
          not (any (Vector.null . primitivePositions) (meshPrimitives (toMesh tilemap)))
    , testCase "centres the map on the origin" $ do
        let corners = meshCorners (room 4)
        minimum [x | V3 x _ _ <- corners] @?= -2
        maximum [x | V3 x _ _ <- corners] @?= 2
        minimum [z | V3 _ _ z <- corners] @?= -2
        maximum [z | V3 _ _ z <- corners] @?= 2
    , -- Coplanar layers would leave the renderer to break the depth tie
      -- however it liked.
      testCase "raises each layer above the one below it" $ do
        let cell = Vector.singleton (Just 1)
            layer name = TileLayer (Text.pack name) 1 1 cell
            mesh = toMesh (Tilemap 1 1 [layer "floor", layer "walls"] [])
        map (map height . Vector.toList . primitivePositions) (meshPrimitives mesh)
          @?= [replicate 4 0, replicate 4 1]
    ]
 where
  height (V3 _ y _) = y

{- | 'toMesh' branches on whether a layer has anything in it, so a run that
never generated one of each says nothing about the branch it skipped.
-}
overLayerKinds :: Testable prop => Tilemap -> prop -> Property
overLayerKinds tilemap =
  checkCoverage
    . cover 40 (any occupied layers) "a layer with a filled cell"
    . cover 10 (not (all occupied layers)) "a layer with no filled cell"
 where
  layers = tilemapLayers tilemap
  occupied = Vector.any isJust . tileLayerTiles

selectsOwnVertex :: Primitive -> Bool
selectsOwnVertex prim =
  all (\i -> fromIntegral i < Vector.length (primitivePositions prim)) (primitiveIndices prim)

meshCorners :: Tilemap -> [V3 Float]
meshCorners = concatMap (Vector.toList . primitivePositions) . meshPrimitives . toMesh

-- | A square map of one wholly filled layer, for assertions about extent.
room :: Int -> Tilemap
room edge = Tilemap edge edge [layer] []
 where
  layer = TileLayer (Text.pack "floor") edge edge (Vector.replicate (edge * edge) (Just 1))
