-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Asset.Animation.PNG
Description : Load a directory of PNG frames into a playable 'Animation.Animation'

Reads the PNG frame sequence a frame-by-frame animation tool exports — one
file per frame, as Pencil2D writes them — and lays the frames side by side
into the single sheet 'Partir.Asset.Sprite' already names. The renderer
therefore uploads one texture and selects a frame from it, exactly as it does
for art that arrived packed.

Frames play in the order their file names sort, which is the order a
zero-padded export numbers them. An export numbering @1.png@ through @10.png@
sorts @10@ second.

Decoding goes through 'PNG.decodeSheet', so the @JuicyPixels@ dependency stays
confined to "Partir.Asset.Sprite.PNG".
-}
module Partir.Asset.Animation.PNG (
  SequenceLoadError (..),
  loadAnimation,
  loadAnimationFrames,
)
where

import Control.Exception (Exception)
import Data.Bifunctor (first)
import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import Data.Char (toLower)
import Data.Foldable (traverse_)
import Data.List (sort)
import qualified Data.Vector as Vector
import qualified Data.Vector.Storable as Storable
import qualified Data.Vector.Storable.Mutable as Mutable
import Data.Word (Word8)
import qualified System.Directory as Directory
import System.FilePath (takeExtension, (</>))

import qualified Partir.Asset.Animation as Animation
import qualified Partir.Asset.Sprite as Sprite
import qualified Partir.Asset.Sprite.PNG as PNG

{- | A frame sequence this loader could not turn into an animation. The
'Exception' instance lets a caller 'Control.Exception.throwIO' it where a
missing animation is fatal, as the client does at startup.
-}
data SequenceLoadError
  = -- | The directory holds no PNG frames, so the path names the wrong place.
    EmptySequence FilePath
  | -- | The named frame is not a PNG.
    UndecodableFrame FilePath PNG.PngLoadError
  deriving Show

instance Exception SequenceLoadError

{- | Load a directory of PNG frames as one animation played at the given rate.
A frame that will not decode is anticipated, so it comes back as a 'Left'; a
missing or unreadable directory is an I\/O failure and surfaces as the
'IOError' thrown by listing it.

Files that are not PNGs are skipped, so a manifest or a project file living
beside the frames does not become one.
-}
loadAnimation ::
  Animation.Rate -> FilePath -> IO (Either SequenceLoadError Animation.Animation)
loadAnimation rate directory = do
  paths <- map (directory </>) . sort . filter isPng <$> Directory.listDirectory directory
  frames <- traverse ByteString.readFile paths
  pure $ case zip paths frames of
    [] -> Left (EmptySequence directory)
    sequenced -> loadAnimationFrames rate sequenced

isPng :: FilePath -> Bool
isPng = (== ".png") . map toLower . takeExtension

{- | Build an animation from frames already in memory, in playing order, each
labelled by where it came from so a decode failure can name it. Under the same
contract as 'loadAnimation', for content that arrives from somewhere other
than a directory.

No frames compose into an animation with nothing to play. Only 'loadAnimation'
reads that as an error, because there it means the path named the wrong place.
-}
loadAnimationFrames ::
  Animation.Rate ->
  [(FilePath, ByteString)] ->
  Either SequenceLoadError Animation.Animation
loadAnimationFrames rate frames = compose rate <$> traverse decode frames
 where
  decode (name, bytes) = first (UndecodableFrame name) (PNG.decodeSheet bytes)

-- | Pair the packed frames with how long each of them holds.
compose :: Animation.Rate -> [Sprite.Sprite] -> Animation.Animation
compose rate frames =
  Animation.Animation
    { Animation.animationSheet = packed frames
    , Animation.animationDurations = Animation.rateDurations rate (length frames)
    }

{- | Lay the decoded frames side by side into one sheet.

Frames sit flush against each other in one row, each keeping its own size, so
a sequence whose frames differ in extent wastes no texels and no frame
addresses its neighbour's. The row is as tall as the tallest frame, and a
shorter one sits against its top edge over transparent pixels.
-}
packed :: [Sprite.Sprite] -> Sprite.Sprite
packed frames =
  Sprite.Sprite
    { Sprite.spriteWidth = sheetWidth
    , Sprite.spriteHeight = sheetHeight
    , Sprite.spritePixels = composite sheetWidth sheetHeight placed
    , Sprite.spriteFrames = Vector.fromList (map (uncurry region) placed)
    }
 where
  sheetWidth = sum (map Sprite.spriteWidth frames)
  sheetHeight = maximum (0 : map Sprite.spriteHeight frames)
  placed = zip (scanl (+) 0 (map Sprite.spriteWidth frames)) frames

-- | The region a frame laid down at the given offset occupies.
region :: Int -> Sprite.Sprite -> Sprite.Frame
region x frame =
  Sprite.Frame
    { Sprite.frameX = x
    , Sprite.frameY = 0
    , Sprite.frameWidth = Sprite.spriteWidth frame
    , Sprite.frameHeight = Sprite.spriteHeight frame
    }

{- | Fill a sheet of the given extent with each frame's pixels, at the offset
it was placed at. Whatever no frame covers keeps the transparent fill.
-}
composite :: Int -> Int -> [(Int, Sprite.Sprite)] -> Storable.Vector Word8
composite sheetWidth sheetHeight placed = Storable.create $ do
  sheet <- Mutable.new (sheetWidth * sheetHeight * channels)
  Mutable.set sheet transparent
  traverse_ (uncurry (blit sheet)) placed
  pure sheet
 where
  -- A frame's rows are contiguous in its own buffer and stride the sheet's
  -- width in the composite, so each one copies whole.
  blit sheet x frame = traverse_ row [0 .. Sprite.spriteHeight frame - 1]
   where
    width = Sprite.spriteWidth frame
    row y =
      Storable.copy
        (Mutable.slice ((y * sheetWidth + x) * channels) (width * channels) sheet)
        (Storable.slice (y * width * channels) (width * channels) (Sprite.spritePixels frame))

-- | Bytes per pixel in the RGBA sheet 'PNG.decodeSheet' hands over.
channels :: Int
channels = 4

-- | The fill an uncovered pixel of the composite keeps: fully transparent black.
transparent :: Word8
transparent = 0
