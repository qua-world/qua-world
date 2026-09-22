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
sheet assembled with its rows or its frames in the wrong order keeps the
dimensions it claims, so only the pixels give that away.
-}
pixelAt :: Sprite -> Int -> Int -> [Word8]
pixelAt sheet x y =
  [ spritePixels sheet Storable.! ((y * spriteWidth sheet + x) * 4 + channel)
  | channel <- [0 .. 3]
  ]
