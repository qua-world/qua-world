-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Partir.Asset.SpriteSpec (
  test_gridFrames,
)
where

import qualified Data.Vector as Vector
import Test.QuickCheck (Property, arbitrary, checkCoverage, cover, forAllShrink, shrink)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (testProperty)

import Partir.Arbitrary (Sheet (..))
import Partir.Asset.Sprite (Frame (..), Grid (..), gridFrames)

test_gridFrames :: TestTree
test_gridFrames =
  testGroup
    "gridFrames"
    [ testCase "walks a sheet left to right and then down" $
        gridFrames (Grid 2 2) 4 4
          @?= Vector.fromList
            [ Frame 0 0 2 2
            , Frame 2 0 2 2
            , Frame 0 2 2 2
            , Frame 2 2 2 2
            ]
    , -- Rounding a partial cell up instead of dropping it would draw a frame
      -- reaching past the art into whatever the sheet's edge samples.
      testCase "drops the remainder a cell does not divide" $
        gridFrames (Grid 2 2) 5 5 @?= gridFrames (Grid 2 2) 4 4
    , testCase "yields nothing for a sheet narrower than one cell" $
        gridFrames (Grid 8 8) 4 8 @?= Vector.empty
    , testCase "yields nothing for a cell of no extent" $
        gridFrames (Grid 0 8) 16 16 @?= Vector.empty
    , testProperty "keeps every frame inside the sheet" framesFitTheSheet
    ]

{- | A frame that reaches past the sheet samples whatever the texture clamps or
wraps to, not the art.
-}
framesFitTheSheet :: Property
framesFitTheSheet = checkCoverage $ forAllShrink arbitrary shrink $ \sheet ->
  let frames = gridFrames (sheetGrid sheet) (sheetWidth sheet) (sheetHeight sheet)
   in cover 20 (not (Vector.null frames)) "the sheet holds a whole cell"
        . cover 20 (Vector.null frames) "the sheet holds none"
        $ all (within sheet) frames
 where
  within sheet frame =
    frameX frame >= 0
      && frameY frame >= 0
      && frameX frame + frameWidth frame <= sheetWidth sheet
      && frameY frame + frameHeight frame <= sheetHeight sheet
