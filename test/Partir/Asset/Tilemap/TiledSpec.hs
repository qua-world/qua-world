-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Partir.Asset.Tilemap.TiledSpec (
  test_loadTilemap,
  test_decodeTilemap,
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
import Partir.Asset.Tilemap.Tiled (
  TiledLoadError (..),
  decodeTilemap,
  loadTilemap,
 )
import Paths_partir_qua_world (getDataFileName)

{- | @examples/level.tmj@ is a hand-written stand-in for a Tiled export: a
6x6 room of a floor layer under a wall layer that rings its border, and one
@player-start@ object on the centre cell of a 16-pixel grid. These
expectations track that file.
-}
test_loadTilemap :: TestTree
test_loadTilemap =
  testGroup
    "loadTilemap"
    [ testCase "reads the tile layers in the order the editor stacks them" $ do
        tilemap <- loadRoom
        map tileLayerName (tilemapLayers tilemap) @?= map Text.pack ["floor", "walls"]
    , testCase "sizes the map by the grid its layers declare" $ do
        tilemap <- loadRoom
        (tilemapColumns tilemap, tilemapRows tilemap) @?= (6, 6)
    , testCase "fills every cell of the floor" $ do
        floorLayer <- layerNamed "floor" =<< loadRoom
        filled floorLayer @?= 36
    , -- A global ID of zero means an empty cell rather than tile zero, and
      -- reading it as a tile would pave the room the walls ring.
      testCase "leaves the cells inside the walls empty" $ do
        walls <- layerNamed "walls" =<< loadRoom
        filled walls @?= 20
        Vector.toList (tileLayerTiles walls) !! 7 @?= Nothing
    , testCase "measures an object group's objects in tile units" $ do
        tilemap <- loadRoom
        tilemapPlacements tilemap
          @?= [ Placement
                  { placementName = Text.pack "player-start"
                  , placementOrigin = V2 3 3
                  , placementSize = V2 1 1
                  }
              ]
    ]

test_decodeTilemap :: TestTree
test_decodeTilemap =
  testGroup
    "decodeTilemap"
    [ testCase "returns the decode failure for bytes that are not a Tiled map" $
        case decodeTilemap (ByteString.pack "not a map") of
          Left (TiledDecodeError _) -> pure ()
          outcome -> assertFailure ("expected a decode failure, got " ++ show outcome)
    , -- Tiled can write a layer's cells base64-encoded and compressed, which
      -- this loader does not unpack. Naming the layer is what tells an author
      -- which one to re-export.
      testCase "names the layer whose cells it cannot read" $
        case decodeTilemap (ByteString.pack encodedLayer) of
          Left (TiledUnreadableLayer name) -> name @?= Text.pack "packed"
          outcome -> assertFailure ("expected an unreadable layer, got " ++ show outcome)
    ]

loadRoom :: IO Tilemap
loadRoom =
  getDataFileName "examples/level.tmj"
    >>= loadTilemap
    >>= either (assertFailure . show) pure

layerNamed :: String -> Tilemap -> IO TileLayer
layerNamed name tilemap =
  case filter ((== Text.pack name) . tileLayerName) (tilemapLayers tilemap) of
    [layer] -> pure layer
    layers -> assertFailure ("expected one " ++ name ++ " layer, got " ++ show (length layers))

filled :: TileLayer -> Int
filled = Vector.length . Vector.filter isJust . tileLayerTiles

-- | The smallest map Tiled writes with @base64@ tile layer format.
encodedLayer :: String
encodedLayer =
  "{\"height\":1,\"layers\":[{\"compression\":\"\",\"data\":\"AQAAAA==\"\
  \,\"encoding\":\"base64\",\"height\":1,\"id\":1,\"name\":\"packed\"\
  \,\"opacity\":1,\"type\":\"tilelayer\",\"visible\":true,\"width\":1\
  \,\"x\":0,\"y\":0}],\"nextlayerid\":2,\"nextobjectid\":1\
  \,\"orientation\":\"orthogonal\",\"tiledversion\":\"1.11.2\"\
  \,\"tileheight\":16,\"tilesets\":[],\"tilewidth\":16,\"type\":\"map\"\
  \,\"version\":\"1.10\",\"width\":1}"
