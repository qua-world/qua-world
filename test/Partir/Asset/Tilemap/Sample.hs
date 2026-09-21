-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Asset.Tilemap.Sample
Description : The bundled sample levels, and the questions a spec asks of one

@examples/level.tmj@ and @examples/level.ldtk@ are hand-written stand-ins for
what Tiled and LDtk export. Both describe one room: a 6x6 floor with every
cell filled, a wall layer ringing its border, and a spawn on the centre cell
of a 16-pixel grid.

A decode failure ends the test case rather than reaching the assertions.
-}
module Partir.Asset.Tilemap.Sample (
  tiledRoom,
  ldtkRoom,
  layerNamed,
  filledCells,
  cellAt,
)
where

import Control.Monad (join)
import Data.Maybe (isJust)
import qualified Data.Text as Text
import qualified Data.Vector as Vector
import Test.Tasty.HUnit (assertFailure)

import Partir.Asset.Tilemap (
  TileLayer (..),
  Tilemap (..),
 )
import qualified Partir.Asset.Tilemap.LDtk as LDtk
import qualified Partir.Asset.Tilemap.Tiled as Tiled
import Paths_partir_qua_world (getDataFileName)

-- | The room as Tiled exports it.
tiledRoom :: IO Tilemap
tiledRoom = bundled "examples/level.tmj" Tiled.loadTilemap

-- | The same room as LDtk saves it.
ldtkRoom :: IO Tilemap
ldtkRoom = bundled "examples/level.ldtk" LDtk.loadTilemap

bundled :: Show e => FilePath -> (FilePath -> IO (Either e Tilemap)) -> IO Tilemap
bundled name load = getDataFileName name >>= load >>= either (assertFailure . show) pure

-- | The one layer with this name, failing the case when it is not exactly one.
layerNamed :: String -> Tilemap -> IO TileLayer
layerNamed name tilemap =
  case filter ((== Text.pack name) . tileLayerName) (tilemapLayers tilemap) of
    [layer] -> pure layer
    layers -> assertFailure ("expected one " ++ name ++ " layer, got " ++ show (length layers))

-- | How many of a layer's cells hold a tile.
filledCells :: TileLayer -> Int
filledCells = Vector.length . Vector.filter isJust . tileLayerTiles

-- | The tile at a column and row.
cellAt :: Int -> Int -> TileLayer -> Maybe Int
cellAt column row layer =
  join (tileLayerTiles layer Vector.!? (row * tileLayerColumns layer + column))
