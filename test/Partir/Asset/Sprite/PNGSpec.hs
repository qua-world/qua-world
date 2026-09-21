-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Partir.Asset.Sprite.PNGSpec (
  test_loadSprite,
  test_loadSpriteBytes,
)
where

import qualified Data.ByteString.Char8 as ByteString
import qualified Data.Vector as Vector
import qualified Data.Vector.Storable as Storable
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertFailure, testCase, (@?=))

import Partir.Asset.Sprite (Frame (..), Grid (..), Sprite (..))
import Partir.Asset.Sprite.PNG (PngLoadError, loadSprite, loadSpriteBytes)
import Partir.Asset.Sprite.Pixels (pixelAt)
import Paths_partir_qua_world (getDataFileName)

{- | @examples/sprites.png@ is a placeholder standing in for real Pixelorama
content: 64 by 64 pixels holding a 4 by 4 grid of 16-pixel cells. Each cell is
a 12-pixel block inset by two, coloured red by its column and green by its row,
so a frame read from the wrong region shows up as the wrong colour rather than
as a plausible one. These expectations track that file.
-}
test_loadSprite :: TestTree
test_loadSprite =
  testGroup
    "loadSprite"
    [ testCase "reads the sheet's pixel dimensions" $ do
        sheet <- loadIcons
        (spriteWidth sheet, spriteHeight sheet) @?= (64, 64)
    , -- The renderer hands this buffer to glTexImage2D and tells it to read
      -- spriteWidth * spriteHeight * 4 bytes, so a buffer shorter than its
      -- dimensions claim is read past its end.
      testCase "fills four bytes for every pixel the dimensions claim" $ do
        sheet <- loadIcons
        Storable.length (spritePixels sheet)
          @?= spriteWidth sheet * spriteHeight sheet * 4
    , testCase "cuts the sheet into the grid's cells" $ do
        sheet <- loadIcons
        Vector.length (spriteFrames sheet) @?= 16
    , testCase "places the frames left to right and then down" $ do
        sheet <- loadIcons
        spriteFrames sheet Vector.!? 0 @?= Just (Frame 0 0 16 16)
        spriteFrames sheet Vector.!? 5 @?= Just (Frame 16 16 16 16)
        spriteFrames sheet Vector.!? 15 @?= Just (Frame 48 48 16 16)
    , -- A Frame counts its frameY down from the top and the renderer uploads
      -- rows in the order they arrive, so a flipped sheet would read every
      -- frame from the row mirroring it. These two colours come from opposite
      -- ends of the sheet.
      testCase "keeps the sheet's top row first" $ do
        sheet <- loadIcons
        pixelAt sheet 8 8 @?= [40, 40, 200, 255]
        pixelAt sheet 8 56 @?= [40, 220, 125, 255]
    , testCase "keeps the transparent margin around a cell's art" $ do
        sheet <- loadIcons
        pixelAt sheet 0 0 @?= [0, 0, 0, 0]
    ]

test_loadSpriteBytes :: TestTree
test_loadSpriteBytes =
  testGroup
    "loadSpriteBytes"
    [ testCase "returns the decode failure for bytes that are not a PNG" $
        case loadSpriteBytes cell (ByteString.pack "not a png") :: Either PngLoadError Sprite of
          Left _ -> pure ()
          Right _ -> assertFailure "expected a decode failure"
    ]

-- | The cell @examples/sprites.png@ is laid out on.
cell :: Grid
cell = Grid{gridFrameWidth = 16, gridFrameHeight = 16}

-- | Load the example sheet, failing the test case with the decode error.
loadIcons :: IO Sprite
loadIcons =
  getDataFileName "examples/sprites.png"
    >>= loadSprite cell
    >>= either (assertFailure . show) pure
