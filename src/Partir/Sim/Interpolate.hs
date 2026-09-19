{- |
Module      : Partir.Sim.Interpolate
Description : Smooth remote agents by interpolating buffered pose samples
Copyright   : (c) Alex Brandt, 2026
License     : MIT

Remote agents arrive as a sparse, jittery stream of pose 'Sample's. Rendering
them at the latest sample makes them teleport; rendering a continuously
'interpolate'd 'Pose' makes them glide. Following the standard snapshot
interpolation approach (Valve's @cl_interp@, Gambetta, Gaffer On Games), the
client plays remote agents back on a clock held a fixed delay /in the past/, so
the two samples bracketing that delayed instant have almost always arrived and
a pose can be blended between them.

Time is measured in ticks throughout: a 'Sample' at @'Tick' n@ sits at
'RenderTime' @n@, and the playback clock advances continuously through
fractional ticks. Keeping one unit avoids threading a tick-rate constant and
leaves the whole module @IO@-free and total.
-}
module Partir.Sim.Interpolate (
  Sample (..),
  RenderTime (..),
  RemoteHistory,
  emptyHistory,
  record,
  interpolate,
)
where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map

import Linear.Quaternion (slerp)
import Linear.Vector (lerp)

import Partir.World.Types (Pose (..), Tick (..))

{- | A remote agent's observed pose at a single tick. Narrower than a networking
/snapshot/ (a whole-scene capture) — one agent, one instant.
-}
data Sample = Sample
  { sampleTick :: Tick
  , samplePose :: Pose
  }
  deriving (Eq, Show)

{- | The playback clock, in ticks. Continuous: a sample at @'Tick' n@ sits at
@'RenderTime' n@, and the clock passes through the fractional ticks between.
-}
newtype RenderTime = RenderTime Double
  deriving (Eq, Ord, Show)

{- | A remote agent's samples, keyed by tick. Backing them with a
'Data.Map.Strict.Map' gives the ascending order and one-pose-per-tick for
free; build it with 'emptyHistory' and 'record'.
-}
newtype RemoteHistory = RemoteHistory (Map Tick Pose)
  deriving (Eq, Show)

-- | A history with no samples yet.
emptyHistory :: RemoteHistory
emptyHistory = RemoteHistory Map.empty

{- | Add a sample. A sample replaces any earlier one bearing the same tick, so
re-sends never duplicate an instant.
-}
record :: Sample -> RemoteHistory -> RemoteHistory
record (Sample t p) (RemoteHistory m) = RemoteHistory (Map.insert t p m)

{- | Interpolate a remote agent's pose for a render frame, extrapolating up to
@horizon@ ticks when the next sample is late.

The pose is sampled at @now - delay@: the two samples bracketing that instant
are blended, position by linear interpolation and orientation by 'slerp'.

Past the newest sample the same blend continues beyond the second of its two
poses, projecting the agent along the velocity the last two samples imply —
dead reckoning, as in Valve's @cl_extrapolate@. The projection stops @horizon@
ticks past the newest sample, so a long gap settles on a fixed pose instead of
drifting without bound; a @horizon@ of @'Tick' 0@ holds the newest pose
outright. A history with one sample holds it, velocity being undefined.

Before the oldest sample the oldest pose is held: there is no earlier motion
to project from. An empty history yields 'Nothing'.
-}
interpolate :: Tick -> Tick -> RenderTime -> RemoteHistory -> Maybe Pose
interpolate (Tick delay) (Tick horizon) (RenderTime now) (RemoteHistory m) =
  case (Map.lookupMax atOrBefore, Map.lookupMin after) of
    (Just (t0, p0), Just (t1, p1)) -> Just (blend (alphaAt target t0 t1) p0 p1)
    (Just (t1, p1), Nothing) -> Just (project t1 p1)
    (Nothing, Just (_, p1)) -> Just p1
    (Nothing, Nothing) -> Nothing
 where
  target = now - fromIntegral delay
  (atOrBefore, after) = Map.spanAntitone (\t -> tickTime t <= target) m
  alphaAt t t0 t1 = (t - tickTime t0) / (tickTime t1 - tickTime t0)

  -- Dead reckoning from the last two samples: dropping the newest leaves the
  -- one before, and their blend runs on as far as the horizon reaches.
  project t1 p1 = case Map.lookupMax (Map.delete t1 atOrBefore) of
    Just (t0, p0) -> blend (alphaAt reached t0 t1) p0 p1
    Nothing -> p1
   where
    reached = min target (tickTime t1 + fromIntegral horizon)

{- | Blend two poses at @alpha@: @alpha = 0@ is the first pose, @alpha = 1@ the
second. Both 'lerp' (since linear 1.23) and 'slerp' run in that direction, and
both continue the straight line and the great-circle arc past @alpha = 1@,
which is what extrapolation rides.
-}
blend :: Double -> Pose -> Pose -> Pose
blend alpha a b =
  Pose
    (lerp alpha (posePosition a) (posePosition b))
    (slerp (poseOrientation a) (poseOrientation b) alpha)

tickTime :: Tick -> Double
tickTime (Tick n) = fromIntegral n
