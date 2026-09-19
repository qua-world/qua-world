-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Sim.Interpolate
Description : Smooth remote agents by interpolating buffered pose samples

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
  Delay (..),
  Horizon (..),
  RemoteHistory,
  emptyHistory,
  record,
  prune,
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

{- | How far behind the present the playback clock runs. A wider delay gives
late samples more time to arrive, and leaves remote agents further behind
what the server knows.
-}
newtype Delay = Delay Tick
  deriving (Eq, Ord, Show)

{- | How far past the newest sample extrapolation projects before it holds.
@'Horizon' ('Tick' 0)@ holds at once, and any horizon bounds how far a long
gap carries the pose from where the agent really is.
-}
newtype Horizon = Horizon Tick
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

{- | Discard the samples the playback clock has passed.

The clock only advances, so samples below the pair 'reckonFrom' names are
dead weight. Keeping that pair and its successors leaves 'interpolate'
unchanged from @now - delay@ on.

Recording does not prune; the render loop calls this at its own cadence.
-}
prune :: Delay -> RenderTime -> RemoteHistory -> RemoteHistory
prune delay now (RemoteHistory m) = RemoteHistory (Map.union reckonable after)
 where
  (atOrBefore, after) = splitAtPlayback (playbackInstant delay now) m
  reckonable = Map.fromList (reckonFrom atOrBefore)

{- | The pose to draw a remote agent at, sampled at @now@ less the 'Delay'.
An empty history yields 'Nothing'.

Samples bracketing that instant are blended, position linearly and orientation
by 'slerp'. Before the oldest sample the oldest pose is held.

Past the newest, the agent is projected along the velocity the last two
samples imply — dead reckoning, as in Valve's @cl_extrapolate@ — and holds
once the 'Horizon' runs out, or at once given a single sample.
-}
interpolate :: Delay -> Horizon -> RenderTime -> RemoteHistory -> Maybe Pose
interpolate delay horizon now (RemoteHistory m) =
  case (Map.lookupMax atOrBefore, Map.lookupMin after) of
    (Just (t0, p0), Just (t1, p1)) -> Just (blend (alphaAt target t0 t1) p0 p1)
    (Just (_, newest), Nothing) -> Just (project newest)
    (Nothing, Just (_, p1)) -> Just p1
    (Nothing, Nothing) -> Nothing
 where
  target = playbackInstant delay now
  (atOrBefore, after) = splitAtPlayback target m
  alphaAt t t0 t1 = (t - tickTime t0) / (tickTime t1 - tickTime t0)

  project newest = case reckonFrom atOrBefore of
    (t1, p1) : (t0, p0) : _ -> blend (alphaAt (reached t1) t0 t1) p0 p1
    _ -> newest
  reached t1 = min target (tickTime t1 + reachTicks horizon)

playbackInstant :: Delay -> RenderTime -> Double
playbackInstant (Delay (Tick delay)) (RenderTime now) = now - fromIntegral delay

reachTicks :: Horizon -> Double
reachTicks (Horizon (Tick n)) = fromIntegral n

{- | The last two samples at or before the playback instant, newest first:
what a projection past the newest reckons its velocity from. 'prune' keeps
exactly these, so a pruned history still carries one.
-}
reckonFrom :: Map Tick Pose -> [(Tick, Pose)]
reckonFrom = take 2 . Map.toDescList

{- | 'interpolate' blends across this boundary and 'prune' cuts below it. Were
the two to disagree on which side the boundary sample falls, pruning would drop
a sample interpolation still reads.
-}
splitAtPlayback :: Double -> Map Tick Pose -> (Map Tick Pose, Map Tick Pose)
splitAtPlayback target = Map.spanAntitone (\t -> tickTime t <= target)

{- | Blend two poses at @alpha@: @alpha = 0@ is the first pose, @alpha = 1@ the
second. Both 'lerp' (since linear 1.23) and 'slerp' run in that direction, and
both extend past @alpha = 1@: 'lerp' along the line, 'slerp' along the arc.
-}
blend :: Double -> Pose -> Pose -> Pose
blend alpha a b =
  Pose
    (lerp alpha (posePosition a) (posePosition b))
    (slerp (poseOrientation a) (poseOrientation b) alpha)

tickTime :: Tick -> Double
tickTime (Tick n) = fromIntegral n
