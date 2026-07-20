{-|
Module      : Partir.Sim.Interpolate
Description : Smooth remote agents by interpolating buffered snapshots
Copyright   : (c) Alex Brandt, 2026
License     : MIT

Remote agents arrive as a sparse, jittery stream of 'Snapshot's. Rendering them
at the latest snapshot makes them teleport; rendering a continuously
'interpolate'd 'Pose' makes them glide. Following the standard snapshot
interpolation approach (Valve's @cl_interp@, Gambetta, Gaffer On Games), the
client plays remote agents back on a clock held a fixed delay /in the past/, so
the two snapshots bracketing that delayed instant have almost always arrived and
a pose can be blended between them.

Time is measured in ticks throughout: a 'Snapshot' at @'Tick' n@ sits at
'RenderTime' @n@, and the playback clock advances continuously through
fractional ticks. Keeping one unit avoids threading a tick-rate constant and
leaves the whole module @IO@-free and total.
-}
module Partir.Sim.Interpolate
  ( Snapshot (..)
  , RenderTime (..)
  , RemoteHistory
  , emptyHistory
  , record
  , snapshots
  , interpolate
  )
where

import Linear.Quaternion (slerp)
import Linear.Vector ((*^), (^+^), (^-^))

import Partir.World.Types (Pose (..), Tick (..))

-- | A remote agent's observed pose at a single tick.
data Snapshot = Snapshot
  { snapshotTick :: Tick
  , snapshotPose :: Pose
  }
  deriving (Eq, Show)

-- | The playback clock, in ticks. Continuous: a snapshot at @'Tick' n@ sits at
-- @'RenderTime' n@, and the clock passes through the fractional ticks between.
newtype RenderTime = RenderTime Double
  deriving (Eq, Ord, Show)

-- | A buffer of a remote agent's snapshots, held in ascending tick order with
-- at most one snapshot per tick. Build it with 'emptyHistory' and 'record'.
newtype RemoteHistory = RemoteHistory [Snapshot]
  deriving (Eq, Show)

-- | A history with no snapshots yet.
emptyHistory :: RemoteHistory
emptyHistory = RemoteHistory []

-- | Add a snapshot, preserving ascending tick order. A snapshot replaces any
-- earlier one bearing the same tick, so re-sends never duplicate an instant.
record :: Snapshot -> RemoteHistory -> RemoteHistory
record s (RemoteHistory ss) = RemoteHistory (insert ss)
  where
    t = snapshotTick s
    insert [] = [s]
    insert (x : xs) = case compare t (snapshotTick x) of
      LT -> s : x : xs
      EQ -> s : xs
      GT -> x : insert xs

-- | The buffered snapshots, oldest first.
snapshots :: RemoteHistory -> [Snapshot]
snapshots (RemoteHistory ss) = ss

-- | Interpolate a remote agent's pose for a render frame.
--
-- The pose is sampled at @now - delay@: the two snapshots bracketing that
-- instant are blended, position by linear interpolation and orientation by
-- 'slerp'. Before the oldest snapshot the oldest pose is held; past the newest,
-- the newest is held (no extrapolation). An empty history yields 'Nothing'.
interpolate :: Tick -> RenderTime -> RemoteHistory -> Maybe Pose
interpolate (Tick delay) (RenderTime now) (RemoteHistory ss) = go ss
  where
    target = now - fromIntegral delay

    go [] = Nothing
    go [s] = Just (snapshotPose s)
    go (s0 : s1 : rest)
      | target <= t0 = Just (snapshotPose s0)
      | target >= t1 = go (s1 : rest)
      | otherwise = Just (blend alpha (snapshotPose s0) (snapshotPose s1))
      where
        t0 = tickTime s0
        t1 = tickTime s1
        alpha = (target - t0) / (t1 - t0)

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

tickTime :: Snapshot -> Double
tickTime s = let Tick n = snapshotTick s in fromIntegral n
