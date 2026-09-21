-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Asset.Tilemap
Description : Authored tile grids and entity placements, independent of any editor

A 'Tilemap' is what a level editor produces: layers of tile cells over a fixed
grid, plus the entities an author placed on it. The type names no editor, so
each loader under @Partir.Asset.Tilemap.*@ converts into this vocabulary and
the client depends only on it.

Every coordinate is in tile units rather than pixels. An editor's tile size is
a property of its source art, not of the level, so each loader divides it out
and one cell is one unit here.

'toMesh' turns the grid into geometry the renderer already draws: cells lie in
the XZ plane with Y up, and the map is centred on the origin.
-}
module Partir.Asset.Tilemap (
  Tilemap (..),
  TileLayer (..),
  Placement (..),
  tileCount,
  toMesh,
)
where

import Data.Maybe (isJust)
import Data.Text (Text)
import Data.Vector (Vector)
import qualified Data.Vector as Vector
import Data.Word (Word32)
import Linear.V2 (V2 (..))
import Linear.V3 (V3 (..))

import qualified Partir.Asset as Asset

-- | One authored level: its grid, the layers painted on it, and what stands on it.
data Tilemap = Tilemap
  { tilemapColumns :: Int
  -- ^ Cells across the widest layer.
  , tilemapRows :: Int
  -- ^ Cells down the tallest layer.
  , tilemapLayers :: [TileLayer]
  -- ^ Tile layers, bottom first.
  , tilemapPlacements :: [Placement]
  -- ^ Entities the author positioned, in source order.
  }
  deriving (Eq, Show)

-- | One layer's cells.
data TileLayer = TileLayer
  { tileLayerName :: Text
  -- ^ The name the author gave the layer.
  , tileLayerColumns :: Int
  -- ^ Cells across.
  , tileLayerRows :: Int
  -- ^ Cells down.
  , tileLayerTiles :: Vector (Maybe Int)
  {- ^ The tile drawn in each cell, 'Nothing' where the author left it empty.
  Row-major from the top-left corner, @'tileLayerColumns' * 'tileLayerRows'@
  long. The 'Int' identifies the tile within the source document's own
  tilesets, which this vocabulary does not carry.
  -}
  }
  deriving (Eq, Show)

{- | An entity the author placed on the grid: a spawn point, a trigger, a prop.
What it means is the level's business, so only its name and extent survive the
conversion.
-}
data Placement = Placement
  { placementName :: Text
  -- ^ The entity's identifier in the editor.
  , placementOrigin :: V2 Double
  -- ^ Where it sits, in tile units from the map's top-left corner.
  , placementSize :: V2 Double
  -- ^ How much of the grid it covers, in tile units.
  }
  deriving (Eq, Show)

-- | Cells holding a tile, across every layer.
tileCount :: Tilemap -> Int
tileCount =
  sum . map (Vector.length . Vector.filter isJust . tileLayerTiles) . tilemapLayers

{- | Build the geometry for a tilemap: one quad per filled cell, gathered into
a primitive per layer. Layers that came out empty contribute nothing.

The map is centred on the origin, which is where the client points its camera.
Nothing is scaled to fit: a cell is a unit whatever the grid, so a map wider
than the frustum overruns the window rather than shrinking into it.

Layer @n@ sits at @y = n@. Tile layers stack in the editor, which on a plane
would leave them coplanar and fighting for depth; one unit of separation is
both the fix and the reading a tile game wants, with a floor below and what
stands on it above.
-}
toMesh :: Tilemap -> Asset.Mesh
toMesh tilemap =
  Asset.Mesh (filter hasGeometry (zipWith (layerPrimitive centre) [0 ..] (tilemapLayers tilemap)))
 where
  centre =
    V2
      (fromIntegral (tilemapColumns tilemap) / 2)
      (fromIntegral (tilemapRows tilemap) / 2)
  hasGeometry = not . Vector.null . Asset.primitivePositions

layerPrimitive :: V2 Float -> Float -> TileLayer -> Asset.Primitive
layerPrimitive centre elevation layer =
  Asset.Primitive
    { Asset.primitivePositions = Vector.concatMap corners cells
    , Asset.primitiveIndices = Vector.concatMap quad (Vector.enumFromN 0 (Vector.length cells))
    , Asset.primitiveNormals = Vector.replicate (4 * Vector.length cells) up
    , Asset.primitiveMaterial = Nothing
    }
 where
  cells = Vector.findIndices isJust (tileLayerTiles layer)
  corners = cellCorners centre elevation (tileLayerColumns layer)
  up = V3 0 1 0

{- | A cell's four corners, wound counter-clockwise seen from above so the
face points along its 'up' normal.
-}
cellCorners :: V2 Float -> Float -> Int -> Int -> Vector (V3 Float)
cellCorners (V2 offsetX offsetZ) elevation columns cell =
  Vector.fromList
    [ V3 left elevation bottom
    , V3 right elevation bottom
    , V3 right elevation top
    , V3 left elevation top
    ]
 where
  left = fromIntegral (cell `mod` columns) - offsetX
  right = left + 1
  top = fromIntegral (cell `div` columns) - offsetZ
  bottom = top + 1

-- | The two triangles covering the nth quad of a primitive.
quad :: Int -> Vector Word32
quad n = Vector.map (fromIntegral (4 * n) +) (Vector.fromList [0, 1, 2, 0, 2, 3])
