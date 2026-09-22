-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Asset.Sprite.PNG
Description : Load a PNG sprite sheet into a renderer-ready 'Sprite.Sprite'

Reads a PNG and cuts it into frames, filling the format-neutral
'Sprite.Sprite' the renderer consumes. The @JuicyPixels@ dependency is confined
to this module: none of its image types appear in the returned value.

Whatever channel layout the file uses, the sheet comes back as 8-bit RGBA, so
a caller uploads one pixel format and a palettized or greyscale sheet needs no
separate path.
-}
module Partir.Asset.Sprite.PNG (
  PngLoadError (..),
  loadSprite,
  loadSpriteBytes,
  decodeSheet,
)
where

import Control.Exception (Exception)
import Data.Bifunctor (first)
import Data.ByteString (ByteString)
import qualified Data.Vector as Vector
import qualified System.File.OsPath as File
import System.OsPath (OsPath)

import qualified Codec.Picture as Picture

import qualified Partir.Asset.Sprite as Sprite

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
loadSprite :: Sprite.Grid -> OsPath -> IO (Either PngLoadError Sprite.Sprite)
loadSprite grid path = loadSpriteBytes grid <$> File.readFile' path

{- | Decode in-memory PNG bytes under the same contract as 'loadSprite', for
content that arrives from somewhere other than a file.
-}
loadSpriteBytes :: Sprite.Grid -> ByteString -> Either PngLoadError Sprite.Sprite
loadSpriteBytes grid bytes = cut <$> decodeSheet bytes
 where
  cut sheet =
    sheet
      { Sprite.spriteFrames =
          Sprite.gridFrames grid (Sprite.spriteWidth sheet) (Sprite.spriteHeight sheet)
      }

{- | Decode a PNG into the sheet alone, its frames left empty for the caller
to fill. A caller whose frames come from somewhere other than a grid decodes
through here rather than through a second decoder.
-}
decodeSheet :: ByteString -> Either PngLoadError Sprite.Sprite
decodeSheet bytes =
  toSheet . Picture.convertRGBA8 <$> first PngLoadError (Picture.decodePng bytes)

toSheet :: Picture.Image Picture.PixelRGBA8 -> Sprite.Sprite
toSheet image =
  Sprite.Sprite
    { Sprite.spriteWidth = Picture.imageWidth image
    , Sprite.spriteHeight = Picture.imageHeight image
    , Sprite.spritePixels = Picture.imageData image
    , Sprite.spriteFrames = Vector.empty
    }
