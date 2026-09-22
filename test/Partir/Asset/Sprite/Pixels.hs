-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

-- | Reading a decoded sheet back, for the specs that assert on its pixels.
module Partir.Asset.Sprite.Pixels (
  pixelAt,
)
where

import qualified Data.Vector.Storable as Storable
import Data.Word (Word8)

import Partir.Asset.Sprite (Sprite (..))

{- | The four channels of one pixel, addressed from the sheet's top-left. A
sheet that came back flipped, or one frame short, holds its declared
dimensions either way, so only its pixels give the fault away.
-}
pixelAt :: Sprite -> Int -> Int -> [Word8]
pixelAt sheet x y =
  [ spritePixels sheet Storable.! ((y * spriteWidth sheet + x) * 4 + channel)
  | channel <- [0 .. 3]
  ]
