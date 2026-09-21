-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Partir.Asset.Tilemap.SampleSpec (
  test_samples,
)
where

import Data.Maybe (isJust)
import qualified Data.Vector as Vector
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

import Partir.Asset.Tilemap (
  Placement (..),
  TileLayer (..),
  Tilemap (..),
 )
import Partir.Asset.Tilemap.Sample (ldtkRoom, tiledRoom)

{- | The two sample levels describe the same room in two editors, so what one
loader reads out of its own is what the other reads out of its own. A
transposed row, a flipped axis, or a reversed layer order passes either
loader's expectations and fails here.
-}
test_samples :: TestTree
test_samples =
  testGroup
    "the samples"
    [ testCase "fill the same cells from either editor" $ do
        ldtk <- ldtkRoom
        tiled <- tiledRoom
        map occupancy (tilemapLayers ldtk) @?= map occupancy (tilemapLayers tiled)
    , testCase "put the spawn on the same cell" $ do
        ldtk <- ldtkRoom
        tiled <- tiledRoom
        map placementOrigin (tilemapPlacements ldtk)
          @?= map placementOrigin (tilemapPlacements tiled)
    ]
 where
  occupancy = Vector.toList . Vector.map isJust . tileLayerTiles
