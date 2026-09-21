-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Asset.PNG
Description : Load a PNG sprite sheet into a renderer-ready 'Asset.Sprite'

Reads a PNG and cuts it into frames, filling the format-neutral
'Asset.Sprite' the renderer consumes. The @JuicyPixels@ dependency is confined
to this module: none of its image types appear in the returned value.

Whatever channel layout the file uses, the sheet comes back as 8-bit RGBA, so
a caller uploads one pixel format and a palettized or greyscale sheet needs no
separate path.

Frames come from a 'Asset.Grid' the caller supplies rather than from the file,
which carries no frame metadata of its own (#111).
-}
module Partir.Asset.PNG (
  PngLoadError (..),
  loadSprite,
  loadSpriteBytes,
)
where

import Control.Exception (Exception)
import Data.Bifunctor (first)
import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString

import qualified Codec.Picture as Picture

import qualified Partir.Asset as Asset

{- | A PNG that could not be decoded, carrying the underlying @JuicyPixels@
diagnostic. The 'Exception' instance lets a caller 'Control.Exception.throwIO'
it where a decode failure should be fatal, as the client does at startup.
-}
newtype PngLoadError = PngLoadError String
  deriving Show

instance Exception PngLoadError

{- | Load a PNG sprite sheet, cut into the given cell. A malformed image is
anticipated, so it comes back as a 'Left'; a missing or unreadable file is an
I\/O failure and surfaces as the 'IOError' thrown by reading it.
-}
loadSprite :: Asset.Grid -> FilePath -> IO (Either PngLoadError Asset.Sprite)
loadSprite grid path = loadSpriteBytes grid <$> ByteString.readFile path

{- | Decode in-memory PNG bytes under the same contract as 'loadSprite', for
content that arrives from somewhere other than a file.
-}
loadSpriteBytes :: Asset.Grid -> ByteString -> Either PngLoadError Asset.Sprite
loadSpriteBytes grid bytes =
  toSprite grid . Picture.convertRGBA8 <$> first PngLoadError (Picture.decodePng bytes)

toSprite :: Asset.Grid -> Picture.Image Picture.PixelRGBA8 -> Asset.Sprite
toSprite grid image =
  Asset.Sprite
    { Asset.spriteWidth = width
    , Asset.spriteHeight = height
    , Asset.spritePixels = Picture.imageData image
    , Asset.spriteFrames = Asset.gridFrames grid width height
    }
 where
  width = Picture.imageWidth image
  height = Picture.imageHeight image
