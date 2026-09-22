-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Asset.Sprite.Sample
Description : A sheet in the shape a frame sequence composes into

A sequence loader lays its frames along one row of equal cells, so a spec that
needs a sheet of that shape without decoding one builds it here.

The pixels are empty. What these stand in for is the frame layout, which is
all a caller reading frames rather than art asks about.
-}
module Partir.Asset.Sprite.Sample (
  strip,
  cell,
)
where

import qualified Data.Vector as Vector
import qualified Data.Vector.Storable as Storable

import Partir.Asset.Sprite (Frame (..), Sprite (..))

-- | A sheet cut into the given number of frames, laid out left to right.
strip :: Int -> Sprite
strip count =
  Sprite
    { spriteWidth = cellSize * count
    , spriteHeight = cellSize
    , spritePixels = Storable.empty
    , spriteFrames = Vector.generate count cell
    }

-- | The nth frame of a 'strip'.
cell :: Int -> Frame
cell n =
  Frame
    { frameX = cellSize * n
    , frameY = 0
    , frameWidth = cellSize
    , frameHeight = cellSize
    }

-- | The square cell a 'strip' is laid out on, in pixels.
cellSize :: Int
cellSize = 16
