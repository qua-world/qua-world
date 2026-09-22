-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Asset.Animation
Description : Timed frame sequences over a sprite sheet, independent of any source format

An 'Animation' is a 'Sprite.Sprite' read as a sequence: the sheet's frames in
playing order, each held for a duration. The type names no source format, so
each loader under @Partir.Asset.Animation.*@ converts into this vocabulary and
the renderer depends only on it.

A frame sequence carries no timing of its own, so the durations come from a
'Rate' the caller supplies rather than from the files (#118).

A caller reduces the 'timeline' to whatever it draws from once, then calls
'stepAt' on the durations for every frame it draws.
-}
module Partir.Asset.Animation (
  Animation (..),
  Rate (..),
  rateDurations,
  still,
  timeline,
  totalDuration,
  stepAt,
)
where

import Data.Maybe (fromMaybe)
import Data.Vector (Vector)
import qualified Data.Vector as Vector

import qualified Partir.Asset.Sprite as Sprite

{- | A sheet and how long each of its frames holds.

The sequence runs as far as the shorter of the two, so an animation over the
first few frames of a larger sheet gives durations for those alone.
-}
data Animation = Animation
  { animationSheet :: Sprite.Sprite
  -- ^ The frames, in playing order, and the pixels they address.
  , animationDurations :: Vector Double
  -- ^ How long each frame holds, in seconds.
  }
  deriving (Eq, Show)

-- | How fast a sequence plays, in frames per second.
newtype Rate = Rate
  { ratePerSecond :: Double
  }
  deriving (Eq, Show)

{- | Durations for a sequence of the given length played at a constant rate.
A rate of no frames per second holds every frame for no time, which 'stepAt'
plays as a still.
-}
rateDurations :: Rate -> Int -> Vector Double
rateDurations rate count = Vector.replicate count seconds
 where
  seconds
    | ratePerSecond rate > 0 = 1 / ratePerSecond rate
    | otherwise = 0

{- | A sheet drawn as a still: its first frame, with nothing to advance to.
Lets a caller draw static and animated art down one path.
-}
still :: Sprite.Sprite -> Animation
still sheet =
  Animation{animationSheet = sheet, animationDurations = Vector.singleton 0}

-- | How long one pass through the animation takes, in seconds.
totalDuration :: Animation -> Double
totalDuration = Vector.sum . Vector.map fst . timeline

-- | The frames the animation plays, in order, each with how long it holds.
timeline :: Animation -> Vector (Double, Sprite.Frame)
timeline animation =
  Vector.zip
    (animationDurations animation)
    (Sprite.spriteFrames (animationSheet animation))

{- | Which step of a looping timeline of these durations is showing after the
given seconds. Time before zero winds backwards through the loop, so a caller
offsetting one animation against another need not keep its clock positive.

'Nothing' when there are no steps. Steps that all hold for no time leave
nothing to advance along, so the first one shows for good.
-}
stepAt :: Vector Double -> Double -> Maybe Int
stepAt durations elapsed
  | Vector.null durations = Nothing
  | total <= 0 = Just 0
  | otherwise = Just (fromMaybe (Vector.length durations - 1) (Vector.findIndex (> wrapped) ends))
 where
  total = Vector.sum durations
  wrapped = elapsed - total * fromIntegral (floor (elapsed / total) :: Integer)
  ends = Vector.postscanl' (+) 0 durations
