-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Asset.Sprite
Description : Renderer-ready sprite sheets, independent of any source format

A 'Sprite' is the imagery a client draws: one sheet of pixels and the 'Frame's
it is cut into. The type names no source format, so each loader under
@Partir.Asset.Sprite.*@ converts into this vocabulary and the renderer depends
only on it.

A sheet carries no frame metadata of its own, so the frames come from a 'Grid'
the caller supplies rather than from the file (#111).
-}
module Partir.Asset.Sprite (
  Sprite (..),
  Frame (..),
  Grid (..),
  gridFrames,
)
where

import Data.Vector (Vector)
import qualified Data.Vector as Vector
import qualified Data.Vector.Storable as Storable
import Data.Word (Word8)

{- | A sheet of pixels and the frames drawn from it.

'spritePixels' is four bytes per pixel, red first, laid out row by row with the
image's top row first. A decoder hands the rows over in that order and a
texture upload reads them in it, so neither end flips. A 'Frame' addresses the
sheet the same way, its 'frameY' counting down from the top.
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
neighbour. A cell with no width or height yields no frames.
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
