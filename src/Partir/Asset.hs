-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Asset
Description : Renderer-ready geometry and imagery, independent of any source format

A 'Mesh' is the geometry a client draws: 'Primitive's, each a triangle list of
positions with optional indices, normals, and a material binding. A 'Sprite' is
the imagery it draws: one sheet of pixels and the 'Frame's it is cut into.
Neither names a source format, so the renderer depends on this vocabulary and
each loader converts into it.

Coordinates are 'Float' rather than the 'Partir.World.Types.Vec3' the
simulation uses: this side of the boundary feeds vertex buffers, and OpenGL
reads single precision.
-}
module Partir.Asset (
  Mesh (..),
  Primitive (..),
  vertexCount,
  indexCount,
  Sprite (..),
  Frame (..),
  Grid (..),
  gridFrames,
)
where

import Data.Vector (Vector)
import qualified Data.Vector as Vector
import qualified Data.Vector.Storable as Storable
import Data.Word (Word32, Word8)
import Linear.V3 (V3)

-- | A drawable asset: the flattened primitives of every mesh in a source file.
newtype Mesh = Mesh
  { meshPrimitives :: [Primitive]
  -- ^ Draw calls, in source order.
  }
  deriving (Eq, Show)

-- | One triangle-list draw call.
data Primitive = Primitive
  { primitivePositions :: Vector (V3 Float)
  -- ^ Vertex positions in model space.
  , primitiveIndices :: Vector Word32
  {- ^ Triangle indices into 'primitivePositions'. Empty draws the positions in
  order.
  -}
  , primitiveNormals :: Vector (V3 Float)
  -- ^ Per-vertex normals, or empty when the source omits them.
  , primitiveMaterial :: Maybe Int
  -- ^ Index of the bound material in the source document, if any.
  }
  deriving (Eq, Show)

-- | Total vertices across every primitive.
vertexCount :: Mesh -> Int
vertexCount = sum . map (Vector.length . primitivePositions) . meshPrimitives

-- | Total triangle indices across every primitive.
indexCount :: Mesh -> Int
indexCount = sum . map (Vector.length . primitiveIndices) . meshPrimitives

{- | A sheet of pixels and the frames drawn from it.

'spritePixels' is four bytes per pixel, red first, laid out row by row with the
image's top row first — the order a texture upload reads and the order a
decoder hands over. A 'Frame' addresses that sheet in the same direction, so
its 'frameY' counts down from the top.
-}
data Sprite = Sprite
  { spriteWidth :: Int
  -- ^ Width of the whole sheet, in pixels.
  , spriteHeight :: Int
  -- ^ Height of the whole sheet, in pixels.
  , spritePixels :: Storable.Vector Word8
  -- ^ The sheet itself, 8-bit RGBA.
  , spriteFrames :: Vector Frame
  -- ^ The regions a caller draws, in the order the sheet lays them out.
  }
  deriving (Eq, Show)

-- | One rectangular region of a sheet, in pixels from its top-left corner.
data Frame = Frame
  { frameX :: Int
  , frameY :: Int
  , frameWidth :: Int
  , frameHeight :: Int
  }
  deriving (Eq, Show)

{- | The cell a sheet is cut into by 'gridFrames'. A sprite tool that exports
an animation as a sheet writes equal cells in rows and columns, so the cell
size is all a caller needs to recover the frames.
-}
data Grid = Grid
  { gridFrameWidth :: Int
  , gridFrameHeight :: Int
  }
  deriving (Eq, Show)

{- | Cut a sheet of the given pixel width and height into cells, left to right
along each row and then down.

A sheet that is not a whole number of cells across or down keeps the cells it
does hold and drops the remainder: a partial cell would draw a slice of its
neighbour. A cell no larger than nothing tiles a sheet infinitely, so it yields
no frames at all.
-}
gridFrames :: Grid -> Int -> Int -> Vector Frame
gridFrames grid sheetWidth sheetHeight
  | cellWidth <= 0 || cellHeight <= 0 = Vector.empty
  | otherwise =
      Vector.fromList
        [ Frame
            { frameX = column * cellWidth
            , frameY = row * cellHeight
            , frameWidth = cellWidth
            , frameHeight = cellHeight
            }
        | row <- [0 .. rows - 1]
        , column <- [0 .. columns - 1]
        ]
 where
  cellWidth = gridFrameWidth grid
  cellHeight = gridFrameHeight grid
  columns = sheetWidth `div` cellWidth
  rows = sheetHeight `div` cellHeight
