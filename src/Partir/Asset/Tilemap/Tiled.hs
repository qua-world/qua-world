-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Asset.Tilemap.Tiled
Description : Load a Tiled JSON map into a format-neutral 'Tilemap.Tilemap'

Reads the JSON a Tiled map exports (@.tmj@) and converts it into the
'Tilemap.Tilemap' the client consumes. The @aeson-tiled@ dependency is
confined to this module: none of it appears in the returned type.

Tiled's native @.tmx@ goes unread. The one parser for it on Hackage,
@htiled@, pins @containers < 0.6@ and does not solve against the GHC this
package is @tested-with@, so a map reaches the client through Tiled's JSON
export.

Group layers are flattened in place.
-}
module Partir.Asset.Tilemap.Tiled (
  TiledLoadError (..),
  loadTilemap,
  decodeTilemap,
)
where

import Control.Exception (Exception)
import Data.Bifunctor (first)
import Data.ByteString (ByteString)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Vector as Vector
import qualified Data.Vector.Storable as Storable
import qualified System.File.OsPath as File
import System.OsPath (OsPath)

import qualified Codec.Tiled.Layer as Layer
import qualified Codec.Tiled.Layer.Data as LayerData
import qualified Codec.Tiled.Map as Tiled
import qualified Codec.Tiled.Object as Object
import qualified Data.Aeson as Aeson
import qualified Data.Tiled.GID as GID
import Linear.V2 (V2 (..))

import qualified Partir.Asset.Tilemap as Tilemap

{- | A Tiled export this loader could not turn into a tilemap. The 'Exception'
instance lets a caller @throwIO@ it where a bad level is fatal, as the client
does at startup.
-}
data TiledLoadError
  = -- | The document is not the JSON a Tiled map export produces.
    TiledDecodeError String
  | {- | The named tile layer stores its cells as base64 rather than CSV, or as
    an infinite map's chunks rather than one grid. Re-export the map with CSV
    tile layer format and a fixed size.
    -}
    TiledUnreadableLayer Text
  deriving (Eq, Show)

instance Exception TiledLoadError

{- | Load a Tiled JSON map. A malformed document is anticipated, so it comes
back as a 'Left'; a missing file is an I\/O failure and surfaces as the
'IOError' thrown by reading it.
-}
loadTilemap :: OsPath -> IO (Either TiledLoadError Tilemap.Tilemap)
loadTilemap path = decodeTilemap <$> File.readFile' path

{- | Decode in-memory map bytes under the same contract as 'loadTilemap', for
content that arrives from somewhere other than a file.
-}
decodeTilemap :: ByteString -> Either TiledLoadError Tilemap.Tilemap
decodeTilemap bytes =
  first TiledDecodeError (Aeson.eitherDecodeStrict' bytes) >>= fromMap

fromMap :: Tiled.Map -> Either TiledLoadError Tilemap.Tilemap
fromMap tiled = do
  layers <- traverse (fromLayer tiled) (byType Layer.TILELAYER)
  pure
    Tilemap.Tilemap
      { Tilemap.tilemapColumns = Tiled.width tiled
      , Tilemap.tilemapRows = Tiled.height tiled
      , Tilemap.tilemapLayers = layers
      , Tilemap.tilemapPlacements = concatMap (placements tiled) (byType Layer.OBJECTGROUP)
      }
 where
  byType wanted = filter ((== wanted) . Layer.type_) flattened
  flattened = concatMap flatten (Vector.toList (Tiled.layers tiled))

-- | A layer and, for a group, every layer nested under it.
flatten :: Layer.Layer -> [Layer.Layer]
flatten layer =
  layer : concatMap flatten (maybe [] Vector.toList (Layer.layers layer))

fromLayer :: Tiled.Map -> Layer.Layer -> Either TiledLoadError Tilemap.TileLayer
fromLayer tiled layer =
  case Layer.data_ layer of
    Just (LayerData.GIDs gids) ->
      Right
        Tilemap.TileLayer
          { Tilemap.tileLayerName = Layer.name layer
          , Tilemap.tileLayerColumns = columns
          , Tilemap.tileLayerRows = rows
          , -- Padding holds the cells to the grid the layer declares, which a
            -- document whose data array stops short would otherwise break.
            Tilemap.tileLayerTiles =
              Vector.fromListN (columns * rows) (map cell (Storable.toList gids) ++ repeat Nothing)
          }
    _ -> Left (TiledUnreadableLayer (Layer.name layer))
 where
  columns = fromMaybe (Tiled.width tiled) (Layer.width layer)
  rows = fromMaybe (Tiled.height tiled) (Layer.height layer)

{- | The tile a cell draws. Tiled reserves the global ID zero for an empty
cell and packs the flip and rotation flags into the high bits of the rest,
which 'GID.toLocal' strips.
-}
cell :: GID.GID -> Maybe Int
cell gid
  | local == 0 = Nothing
  | otherwise = Just local
 where
  local = GID.toLocal gid

{- | Every object in an object group, measured in tile units. Tiled records an
object's own origin, which for a rectangle is its top-left corner and for a
tile object is its bottom-left.
-}
placements :: Tiled.Map -> Layer.Layer -> [Tilemap.Placement]
placements tiled layer =
  map placement (maybe [] Vector.toList (Layer.objects layer))
 where
  placement object =
    Tilemap.Placement
      { Tilemap.placementName = Object.name object
      , Tilemap.placementOrigin = inTiles (Object.x object) (Object.y object)
      , Tilemap.placementSize = inTiles (Object.width object) (Object.height object)
      }
  inTiles across down =
    V2
      (across / fromIntegral (Tiled.tileWidth tiled))
      (down / fromIntegral (Tiled.tileHeight tiled))
