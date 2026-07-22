{-|
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
module Partir.Sim.Interpolate
  ( Sample (..)
  , RenderTime (..)
  , RemoteHistory
  , emptyHistory
  , record
  , samples
  , interpolate
  )
where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map

import Linear.Quaternion (slerp)
import Linear.Vector ((*^), (^+^), (^-^))

import Partir.World.Types (Pose (..), Tick (..))

-- | A remote agent's observed pose at a single tick. Narrower than a networking
-- /snapshot/ (a whole-scene capture) — one agent, one instant.
data Sample = Sample
  { sampleTick :: Tick
  , samplePose :: Pose
  }
  deriving (Eq, Show)

-- | The playback clock, in ticks. Continuous: a sample at @'Tick' n@ sits at
-- @'RenderTime' n@, and the clock passes through the fractional ticks between.
newtype RenderTime = RenderTime Double
  deriving (Eq, Ord, Show)

-- | A remote agent's samples, keyed by tick. Backing them with a
-- 'Data.Map.Strict.Map' gives the ascending order and one-pose-per-tick for
-- free; build it with 'emptyHistory' and 'record'.
newtype RemoteHistory = RemoteHistory (Map Tick Pose)
  deriving (Eq, Show)

-- | A history with no samples yet.
emptyHistory :: RemoteHistory
emptyHistory = RemoteHistory Map.empty

-- | Add a sample. A sample replaces any earlier one bearing the same tick, so
-- re-sends never duplicate an instant.
record :: Sample -> RemoteHistory -> RemoteHistory
record (Sample t p) (RemoteHistory m) = RemoteHistory (Map.insert t p m)

-- | The buffered samples, oldest first.
samples :: RemoteHistory -> [Sample]
samples (RemoteHistory m) = uncurry Sample <$> Map.toAscList m

-- | Interpolate a remote agent's pose for a render frame.
--
-- The pose is sampled at @now - delay@: the two samples bracketing that instant
-- are blended, position by linear interpolation and orientation by 'slerp'.
-- Before the oldest sample the oldest pose is held; past the newest, the newest
-- is held (no extrapolation). An empty history yields 'Nothing'.
interpolate :: Tick -> RenderTime -> RemoteHistory -> Maybe Pose
interpolate (Tick delay) (RenderTime now) (RemoteHistory m) =
  case (Map.lookupMax atOrBefore, Map.lookupMin after) of
    (Just (t0, p0), Just (t1, p1)) -> Just (blend (alpha t0 t1) p0 p1)
    (Just (_, p0), Nothing) -> Just p0
    (Nothing, Just (_, p1)) -> Just p1
    (Nothing, Nothing) -> Nothing
  where
    target = now - fromIntegral delay
    (atOrBefore, after) = Map.spanAntitone (\t -> tickTime t <= target) m
    alpha t0 t1 = (target - tickTime t0) / (tickTime t1 - tickTime t0)

-- | Blend two poses at @alpha@ in @[0, 1]@: @alpha = 0@ is the first pose,
-- @alpha = 1@ the second. Position is written out longhand rather than via
-- "Linear"'s @lerp@, whose coefficient runs the opposite way.
blend :: Double -> Pose -> Pose -> Pose
blend alpha a b =
  Pose
    (pa ^+^ alpha *^ (pb ^-^ pa))
    (slerp (poseOrientation a) (poseOrientation b) alpha)
  where
    pa = posePosition a
    pb = posePosition b

tickTime :: Tick -> Double
tickTime (Tick n) = fromIntegral n
