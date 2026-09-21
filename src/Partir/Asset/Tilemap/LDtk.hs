-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT
{-# LANGUAGE OverloadedRecordDot #-}

{- |
Module      : Partir.Asset.Tilemap.LDtk
Description : Load an LDtk project into a format-neutral 'Tilemap.Tilemap'

Reads an LDtk project file (@.ldtk@) and converts its first level into the
'Tilemap.Tilemap' the client consumes. The @ldtk-types@ dependency is confined
to this module: none of it appears in the returned type.

@ldtk-types@ names its fields after LDtk's own JSON keys, several of which
repeat across records, so this module reads them through
@OverloadedRecordDot@ rather than through ambiguous selectors.
-}
module Partir.Asset.Tilemap.LDtk (
  LDtkLoadError (..),
  loadTilemap,
  decodeTilemap,
)
where

import Control.Exception (Exception)
import Data.Bifunctor (first)
import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import Data.Maybe (fromMaybe, mapMaybe)
import qualified Data.Vector as Vector

import qualified Data.Aeson as Aeson
import qualified LDtk.Types as LDtk
import Linear.V2 (V2 (..))

import qualified Partir.Asset.Tilemap as Tilemap

{- | An LDtk project this loader could not turn into a tilemap. The
'Exception' instance lets a caller @throwIO@ it where a bad level is fatal, as
the client does at startup.
-}
data LDtkLoadError
  = -- | The document is not the JSON an LDtk project saves.
    LDtkDecodeError String
  | {- | The project holds no level, in its own list or in any of its worlds.
    A project saved with separate level files reads this way, since each level
    then lives in a @.ldtkl@ of its own.
    -}
    LDtkNoLevels
  deriving (Eq, Show)

instance Exception LDtkLoadError

{- | Load an LDtk project's first level. A malformed or levelless document is
anticipated, so it comes back as a 'Left'; a missing or unreadable file is an
I\/O failure and surfaces as the 'IOError' thrown by reading it.
-}
loadTilemap :: FilePath -> IO (Either LDtkLoadError Tilemap.Tilemap)
loadTilemap path = decodeTilemap <$> ByteString.readFile path

{- | Decode in-memory project bytes under the same contract as 'loadTilemap',
for content that arrives from somewhere other than a file.
-}
decodeTilemap :: ByteString -> Either LDtkLoadError Tilemap.Tilemap
decodeTilemap bytes =
  first LDtkDecodeError (Aeson.eitherDecodeStrict' bytes) >>= fromRoot

fromRoot :: LDtk.LDtkRoot -> Either LDtkLoadError Tilemap.Tilemap
fromRoot root =
  case root.levels ++ concatMap (.levels) root.worlds of
    [] -> Left LDtkNoLevels
    level : _ -> Right (fromLevel level)

{- | LDtk lists a level's layers topmost first, which is the order the editor
draws them in; 'Tilemap.tilemapLayers' runs the other way.
-}
fromLevel :: LDtk.Level -> Tilemap.Tilemap
fromLevel level =
  Tilemap.Tilemap
    { Tilemap.tilemapColumns = extent (.__cWid)
    , Tilemap.tilemapRows = extent (.__cHei)
    , Tilemap.tilemapLayers = mapMaybe fromLayer layers
    , Tilemap.tilemapPlacements = concatMap placements layers
    }
 where
  layers = reverse level.layerInstances
  extent cells = maximum (0 : map cells layers)

{- | A layer's cells, however LDtk stored them: painted tiles, the tiles a
rule generated, or the integer grid an author painted behind them. A layer
carrying none of the three holds only entities and contributes no geometry.
-}
fromLayer :: LDtk.Layer -> Maybe Tilemap.TileLayer
fromLayer layer
  | not (null tiles) = Just (cells (placed tiles))
  | not (null layer.intGridCsv) = Just (cells (map painted layer.intGridCsv))
  | otherwise = Nothing
 where
  tiles = layer.gridTiles ++ layer.autoLayerTiles
  columns = layer.__cWid
  rows = layer.__cHei

  cells tileList =
    Tilemap.TileLayer
      { Tilemap.tileLayerName = layer.__identifier
      , Tilemap.tileLayerColumns = columns
      , Tilemap.tileLayerRows = rows
      , -- Padding holds the cells to the grid the layer declares, which a
        -- document whose integer grid stops short would otherwise break.
        Tilemap.tileLayerTiles = Vector.fromListN (columns * rows) (tileList ++ repeat Nothing)
      }

  painted 0 = Nothing
  painted value = Just value

  {- LDtk places a tile by its pixel offset within the layer rather than by
  cell, and lists a cell's tiles in the order they stack, so the last one
  written to a cell is the one on top. -}
  placed =
    Vector.toList
      . (Vector.replicate (columns * rows) Nothing Vector.//)
      . mapMaybe overwrite

  overwrite :: LDtk.Tile -> Maybe (Int, Maybe Int)
  overwrite tile
    | layer.__gridSize <= 0 = Nothing
    | column < 0 || column >= columns = Nothing
    | row < 0 || row >= rows = Nothing
    | otherwise = Just (row * columns + column, Just (fromMaybe 0 tile.t))
   where
    column = tile.px.p_x `div` layer.__gridSize
    row = tile.px.p_y `div` layer.__gridSize

-- | Every entity instance on a layer, measured in that layer's tile units.
placements :: LDtk.Layer -> [Tilemap.Placement]
placements layer = map placement layer.entityInstances
 where
  placement :: LDtk.Entity -> Tilemap.Placement
  placement entity =
    Tilemap.Placement
      { Tilemap.placementName = entity.__identifier
      , Tilemap.placementOrigin = inTiles entity.px.p_x entity.px.p_y
      , Tilemap.placementSize = inTiles entity.width entity.height
      }
  inTiles :: Int -> Int -> V2 Double
  inTiles across down = V2 (scaled across) (scaled down)
  scaled pixels = fromIntegral pixels / fromIntegral (max 1 layer.__gridSize)
