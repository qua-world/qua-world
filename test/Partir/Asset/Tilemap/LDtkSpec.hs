-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Partir.Asset.Tilemap.LDtkSpec (
  test_loadTilemap,
  test_decodeTilemap,
)
where

import qualified Data.ByteString.Char8 as ByteString
import qualified Data.Text as Text
import Linear.V2 (V2 (..))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertFailure, testCase, (@?=))

import Partir.Asset.Tilemap (
  Placement (..),
  TileLayer (..),
  Tilemap (..),
 )
import Partir.Asset.Tilemap.LDtk (LDtkLoadError (..), decodeTilemap)
import Partir.Asset.Tilemap.Sample (
  cellAt,
  filledCells,
  layerNamed,
  ldtkRoom,
 )

-- | Expectations on @examples/level.ldtk@, which "Partir.Asset.Tilemap.Sample" describes.
test_loadTilemap :: TestTree
test_loadTilemap =
  testGroup
    "loadTilemap"
    [ -- LDtk writes a level's layers topmost first, so reading them in file
      -- order would bury the floor under the walls.
      testCase "reverses LDtk's layer order to put the lowest first" $ do
        tilemap <- ldtkRoom
        map tileLayerName (tilemapLayers tilemap) @?= map Text.pack ["Floor", "Walls"]
    , testCase "reads an IntGrid layer's painted values as its cells" $ do
        floorLayer <- layerNamed "Floor" =<< ldtkRoom
        filledCells floorLayer @?= 36
    , -- LDtk gives a grid tile a pixel offset rather than a cell, so a loader
      -- that forgot to divide by the grid size would pile the walls into the
      -- first few cells.
      testCase "places a grid tile in the cell its pixel offset falls in" $ do
        walls <- layerNamed "Walls" =<< ldtkRoom
        filledCells walls @?= 20
        cellAt 1 1 walls @?= Nothing
    , testCase "skips a layer that holds only entities" $ do
        tilemap <- ldtkRoom
        length (tilemapLayers tilemap) @?= 2
    , testCase "measures an entity instance in tile units" $ do
        tilemap <- ldtkRoom
        tilemapPlacements tilemap
          @?= [ Placement
                  { placementName = Text.pack "PlayerStart"
                  , placementOrigin = V2 3 3
                  , placementSize = V2 1 1
                  }
              ]
    ]

test_decodeTilemap :: TestTree
test_decodeTilemap =
  testGroup
    "decodeTilemap"
    [ testCase "returns the decode failure for bytes that are not an LDtk project" $
        case decodeTilemap (ByteString.pack "not a project") of
          Left (LDtkDecodeError _) -> pure ()
          outcome -> assertFailure ("expected a decode failure, got " ++ show outcome)
    , -- A project saved with separate level files parses but carries no level
      -- of its own, which is a different thing to tell an author than a
      -- malformed document.
      testCase "separates a levelless project from a malformed one" $
        decodeTilemap (ByteString.pack levellessProject) @?= Left LDtkNoLevels
    ]

-- | An LDtk project whose levels live in @.ldtkl@ files beside it.
levellessProject :: String
levellessProject =
  "{\"jsonVersion\":\"1.5.3\",\"iid\":\"empty\",\"worldLayout\":\"Free\"\
  \,\"externalLevels\":true,\"bgColor\":\"#40465B\"\
  \,\"defs\":{\"layers\":[],\"entities\":[],\"tilesets\":[],\"enums\":[]\
  \,\"externalEnums\":[]},\"levels\":[],\"worlds\":[]}"
