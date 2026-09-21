-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Partir.Asset.Animation.PNGSpec (
  test_loadAnimation,
  test_loadAnimationFrames,
)
where

import qualified Codec.Picture as Picture
import qualified Data.ByteString.Char8 as ByteString
import qualified Data.ByteString.Lazy as Lazy
import qualified Data.Vector as Vector
import qualified Data.Vector.Storable as Storable
import Data.Word (Word8)
import qualified System.Directory as Directory
import System.FilePath ((</>))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertFailure, testCase, (@?=))

import Partir.Asset.Animation (Animation (..), Rate (..), timeline, totalDuration)
import Partir.Asset.Animation.PNG (SequenceLoadError (..), loadAnimation, loadAnimationFrames)
import Partir.Asset.Sprite (Frame (..), Sprite (..))
import Paths_partir_qua_world (getDataFileName)

{- | @examples/walk/@ is a placeholder standing in for real Pencil2D content:
four 16-pixel frames, numbered @0001.png@ through @0004.png@. Each is a
12-pixel block inset by two, reddening frame by frame, with a white foot
stepping left to right across it, so a sequence read out of order shows up as
a colour jump rather than as a plausible cycle. These expectations track those
files.
-}
test_loadAnimation :: TestTree
test_loadAnimation =
  testGroup
    "loadAnimation"
    [ testCase "plays every frame in the directory" $ do
        walk <- loadWalk
        Vector.length (timeline walk) @?= 4
    , -- One texture is what the renderer uploads, so the frames arrive laid
      -- into a single sheet rather than as four of them.
      testCase "lays the frames side by side into one sheet" $ do
        walk <- loadWalk
        let sheet = animationSheet walk
        (spriteWidth sheet, spriteHeight sheet) @?= (64, 16)
    , testCase "fills four bytes for every pixel the dimensions claim" $ do
        sheet <- animationSheet <$> loadWalk
        Storable.length (spritePixels sheet)
          @?= spriteWidth sheet
            * spriteHeight sheet
            * 4
    , testCase "gives each frame the region it was laid into" $ do
        sheet <- animationSheet <$> loadWalk
        spriteFrames sheet
          @?= Vector.fromList [Frame x 0 16 16 | x <- [0, 16, 32, 48]]
    , -- The frames redden in the order their names sort. Reading them in any
      -- other order puts one of these four colours in the wrong region.
      testCase "orders the frames by the numbers their names carry" $ do
        sheet <- animationSheet <$> loadWalk
        [pixelAt sheet (16 * frame + 8) 8 | frame <- [0 .. 3]]
          @?= [[red, 120, 120, 255] | red <- [40, 100, 160, 220]]
    , -- A frame's own rows have to survive the move into the composite: a
      -- sheet assembled column-first would still be 64 by 16 and still hold
      -- the right colours.
      testCase "keeps each frame's top row first" $ do
        sheet <- animationSheet <$> loadWalk
        pixelAt sheet 3 3 @?= [40, 120, 120, 255]
        pixelAt sheet 3 12 @?= [250, 250, 250, 255]
    , testCase "keeps the transparent margin around a frame's art" $ do
        sheet <- animationSheet <$> loadWalk
        pixelAt sheet 0 0 @?= [0, 0, 0, 0]
    , testCase "holds each frame for the rate the caller gave" $ do
        walk <- loadWalk
        animationDurations walk @?= Vector.replicate 4 0.125
        totalDuration walk @?= 0.5
    , -- Pointing at a directory holding no frames is a mistake worth naming,
      -- rather than an animation that draws nothing.
      testCase "rejects a directory holding no PNG frames" $
        withEmptyDirectory $ \empty -> do
          outcome <- loadAnimation rate empty
          case outcome of
            Left (EmptySequence named) -> named @?= empty
            _ -> assertFailure "expected an empty sequence to be rejected"
    ]

test_loadAnimationFrames :: TestTree
test_loadAnimationFrames =
  testGroup
    "loadAnimationFrames"
    [ testCase "names the frame that would not decode" $
        case loadAnimationFrames rate [("0001.png", ByteString.pack "not a png")] of
          Left (UndecodableFrame named _) -> named @?= "0001.png"
          _ -> assertFailure "expected a decode failure"
    , -- A sequence exported from a tool that trims each frame gives frames of
      -- differing extent. Laying those out in equal cells would either clip
      -- the widest or leave the narrowest sampling its neighbour.
      testCase "gives an uneven frame the extent it came with" $ do
        sheet <- animationSheet <$> composed [(3, 5), (7, 2)]
        (spriteWidth sheet, spriteHeight sheet) @?= (10, 5)
        spriteFrames sheet @?= Vector.fromList [Frame 0 0 3 5, Frame 3 0 7 2]
    , -- The row is as tall as the tallest frame, and what a shorter one does
      -- not cover has to stay clear rather than repeat its last row.
      testCase "leaves the space under a short frame transparent" $ do
        sheet <- animationSheet <$> composed [(3, 5), (7, 2)]
        pixelAt sheet 5 1 @?= [255, 0, 0, 255]
        pixelAt sheet 5 3 @?= [0, 0, 0, 0]
    ]

-- | The rate @examples/walk/@ is drawn to play at.
rate :: Rate
rate = Rate{ratePerSecond = 8}

-- | Load the example sequence, failing the test case with the load error.
loadWalk :: IO Animation
loadWalk =
  getDataFileName "examples/walk"
    >>= loadAnimation rate
    >>= either (assertFailure . show) pure

{- | Compose frames of the given pixel sizes, each filled solid red, failing
the test case with the load error.
-}
composed :: [(Int, Int)] -> IO Animation
composed sizes =
  either (assertFailure . show) pure (loadAnimationFrames rate (zipWith frame [1 :: Int ..] sizes))
 where
  frame n (width, height) =
    ( show n ++ ".png"
    , Lazy.toStrict (Picture.encodePng (Picture.generateImage (const (const red)) width height))
    )
  red = Picture.PixelRGBA8 255 0 0 255

-- | Run an action over a directory holding no frames, and clear it away after.
withEmptyDirectory :: (FilePath -> IO a) -> IO a
withEmptyDirectory action = do
  path <- (</> "partir-empty-sequence") <$> Directory.getTemporaryDirectory
  Directory.createDirectoryIfMissing True path
  action path <* Directory.removeDirectoryRecursive path

-- | The four channels of one pixel, addressed from the sheet's top-left.
pixelAt :: Sprite -> Int -> Int -> [Word8]
pixelAt sheet x y =
  [ spritePixels sheet Storable.! ((y * spriteWidth sheet + x) * 4 + channel)
  | channel <- [0 .. 3]
  ]
