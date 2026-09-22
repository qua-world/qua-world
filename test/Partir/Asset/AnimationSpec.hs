-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Partir.Asset.AnimationSpec (
  test_rateDurations,
  test_timeline,
  test_totalDuration,
  test_stepAt,
)
where

import qualified Data.Vector as Vector
import qualified Data.Vector.Storable as Storable
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

import Partir.Asset.Animation (
  Animation (..),
  Rate (..),
  rateDurations,
  stepAt,
  still,
  timeline,
  totalDuration,
 )
import Partir.Asset.Sprite (Frame (..), Sprite (..))

{- | A rate is what the frames themselves do not carry, so getting it wrong
plays the whole sequence at the wrong speed.
-}
test_rateDurations :: TestTree
test_rateDurations =
  testGroup
    "rateDurations"
    [ testCase "divides a second between the frames played in it" $
        rateDurations (Rate 8) 4 @?= Vector.replicate 4 0.125
    , testCase "gives no durations for no frames" $
        rateDurations (Rate 8) 0 @?= Vector.empty
    , -- Dividing by it would hold every frame forever.
      testCase "holds a frame for no time at a rate of none per second" $
        rateDurations (Rate 0) 2 @?= Vector.replicate 2 0
    ]

{- | Which frames an animation plays, and for how long. The durations decide
how far into the sheet it reaches, which is what lets a still share the path.
-}
test_timeline :: TestTree
test_timeline =
  testGroup
    "timeline"
    [ testCase "pairs each frame with how long it holds" $
        timeline (walk 3) @?= Vector.fromList [(0.5, cell 0), (0.5, cell 1), (0.5, cell 2)]
    , -- An animation over the opening frames of a larger sheet gives
      -- durations for those alone, and the rest are not part of it.
      testCase "plays as far as the durations reach" $
        Vector.length (timeline (walk 3){animationDurations = Vector.fromList [0.5, 0.5]}) @?= 2
    , testCase "plays the one frame a still holds on" $
        timeline (still (sheet 3)) @?= Vector.singleton (0, cell 0)
    ]

test_totalDuration :: TestTree
test_totalDuration =
  testGroup
    "totalDuration"
    [ testCase "adds up one pass through the frames" $
        totalDuration (walk 4) @?= 2
    , testCase "takes no time over a sheet with no frames" $
        totalDuration (walk 0) @?= 0
    ]

{- | Playback itself: which frame the clock has reached. Everything the client
draws of an animation comes through here.
-}
test_stepAt :: TestTree
test_stepAt =
  testGroup
    "stepAt"
    [ testCase "opens on the first step" $
        stepAt evenly 0 @?= Just 0
    , testCase "advances once a step's duration has passed" $
        map (stepAt evenly) [0.4, 0.6, 1.4] @?= [Just 0, Just 1, Just 2]
    , -- The boundary is where an off-by-one shows: a step ends at its own
      -- duration and the next one begins there.
      testCase "hands a step's final instant to the step itself" $
        map (stepAt evenly) [0.499, 0.5] @?= [Just 0, Just 1]
    , testCase "returns to the first step after the last one ends" $
        stepAt evenly 2 @?= Just 0
    , testCase "keeps looping however many passes have gone by" $
        stepAt evenly 100.6 @?= Just 1
    , -- A client offsetting one animation against another runs a clock that
      -- starts before zero.
      testCase "winds backwards through the loop before zero" $
        map (stepAt evenly) [-0.1, -1.1] @?= [Just 3, Just 1]
    , testCase "holds steps of uneven length for their own durations" $
        map (stepAt (Vector.fromList [0.1, 0.9])) [0.05, 0.15, 0.95] @?= [Just 0, Just 1, Just 1]
    , testCase "has no step to show without durations" $
        stepAt Vector.empty 1 @?= Nothing
    , -- Advancing along a timeline of no length would divide by it.
      testCase "holds on the first step when none of them take any time" $
        stepAt (Vector.replicate 3 0) 5 @?= Just 0
    ]

-- | Four steps of half a second each.
evenly :: Vector.Vector Double
evenly = Vector.replicate 4 0.5

-- | A sheet of the given number of frames, played at two frames a second.
walk :: Int -> Animation
walk count =
  Animation
    { animationSheet = sheet count
    , animationDurations = rateDurations (Rate 2) count
    }

-- | A strip of 16-pixel cells laid out the way the sequence loader composes one.
sheet :: Int -> Sprite
sheet count =
  Sprite
    { spriteWidth = 16 * count
    , spriteHeight = 16
    , spritePixels = Storable.empty
    , spriteFrames = Vector.generate count cell
    }

cell :: Int -> Frame
cell n = Frame{frameX = 16 * n, frameY = 0, frameWidth = 16, frameHeight = 16}
