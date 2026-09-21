-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Partir.Asset.Tilemap.LDtkSpec (
  test_loadTilemap,
  test_decodeTilemap,
  test_sampleParity,
)
where

import qualified Data.ByteString.Char8 as ByteString
import Data.Maybe (isJust)
import qualified Data.Text as Text
import qualified Data.Vector as Vector
import Linear.V2 (V2 (..))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertFailure, testCase, (@?=))

import Partir.Asset.Tilemap (
  Placement (..),
  TileLayer (..),
  Tilemap (..),
 )
import Partir.Asset.Tilemap.LDtk (
  LDtkLoadError (..),
  decodeTilemap,
  loadTilemap,
 )
import qualified Partir.Asset.Tilemap.Tiled as Tiled
import Paths_partir_qua_world (getDataFileName)

{- | @examples/level.ldtk@ is a hand-written stand-in for an LDtk project: the
same 6x6 room as @examples/level.tmj@, with the floor painted as an IntGrid,
the walls placed as grid tiles, and a @PlayerStart@ entity on the centre cell
of a 16-pixel grid. These expectations track that file.
-}
test_loadTilemap :: TestTree
test_loadTilemap =
  testGroup
    "loadTilemap"
    [ -- LDtk writes a level's layers topmost first, so reading them in file
      -- order would bury the floor under the walls.
      testCase "reverses LDtk's layer order to put the lowest first" $ do
        tilemap <- loadRoom
        map tileLayerName (tilemapLayers tilemap) @?= map Text.pack ["Floor", "Walls"]
    , testCase "reads an IntGrid layer's painted values as its cells" $ do
        floorLayer <- layerNamed "Floor" =<< loadRoom
        filled floorLayer @?= 36
    , -- LDtk gives a grid tile a pixel offset rather than a cell, so a loader
      -- that forgot to divide by the grid size would pile the walls into the
      -- first few cells.
      testCase "places a grid tile in the cell its pixel offset falls in" $ do
        walls <- layerNamed "Walls" =<< loadRoom
        filled walls @?= 20
        Vector.toList (tileLayerTiles walls) !! 7 @?= Nothing
    , testCase "skips a layer that holds only entities" $ do
        tilemap <- loadRoom
        length (tilemapLayers tilemap) @?= 2
    , testCase "measures an entity instance in tile units" $ do
        tilemap <- loadRoom
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

{- | The two sample levels describe the same room in two editors. Comparing
which cells they fill holds both loaders to one reading of the grid: a
transposed row, a flipped axis, or a reversed layer order shows up here even
though each loader's own expectations still pass.
-}
test_sampleParity :: TestTree
test_sampleParity =
  testGroup
    "the samples"
    [ testCase "fill the same cells from either editor" $ do
        room <- loadRoom
        tiled <- loadTiledRoom
        map occupancy (tilemapLayers room) @?= map occupancy (tilemapLayers tiled)
    , testCase "put the spawn on the same cell" $ do
        room <- loadRoom
        tiled <- loadTiledRoom
        map placementOrigin (tilemapPlacements room)
          @?= map placementOrigin (tilemapPlacements tiled)
    ]
 where
  occupancy = Vector.toList . Vector.map isJust . tileLayerTiles

loadRoom :: IO Tilemap
loadRoom =
  getDataFileName "examples/level.ldtk"
    >>= loadTilemap
    >>= either (assertFailure . show) pure

loadTiledRoom :: IO Tilemap
loadTiledRoom =
  getDataFileName "examples/level.tmj"
    >>= Tiled.loadTilemap
    >>= either (assertFailure . show) pure

layerNamed :: String -> Tilemap -> IO TileLayer
layerNamed name tilemap =
  case filter ((== Text.pack name) . tileLayerName) (tilemapLayers tilemap) of
    [layer] -> pure layer
    layers -> assertFailure ("expected one " ++ name ++ " layer, got " ++ show (length layers))

filled :: TileLayer -> Int
filled = Vector.length . Vector.filter isJust . tileLayerTiles

-- | An LDtk project whose levels live in @.ldtkl@ files beside it.
levellessProject :: String
levellessProject =
  "{\"jsonVersion\":\"1.5.3\",\"iid\":\"empty\",\"worldLayout\":\"Free\"\
  \,\"externalLevels\":true,\"bgColor\":\"#40465B\"\
  \,\"defs\":{\"layers\":[],\"entities\":[],\"tilesets\":[],\"enums\":[]\
  \,\"externalEnums\":[]},\"levels\":[],\"worlds\":[]}"
