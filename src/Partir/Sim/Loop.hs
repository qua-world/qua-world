-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Sim.Loop
Description : Step the scene at a fixed rate, apart from rendering

The client steps its 'Scene' at a fixed 'TickRate', whatever rate the
renderer draws at. Coupling the two makes motion depend on the framerate,
lets fast movers skip past collisions, and turns frame jitter into simulation
jitter (Lopes, "The Basics"; Fiedler, "Fix Your Timestep!").

Wall-clock time arrives in uneven slices. 'accumulate' turns them into whole
steps and carries the leftover fraction, so the step count tracks elapsed time
however the slices fall.
-}
module Partir.Sim.Loop (
  DeltaTime (..),
  TickRate (..),
  Backlog (..),
  noBacklog,
  maxElapsed,
  accumulate,
  step,
  Instant (..),
  Clock (..),
  SceneStore (..),
  runLoop,
)
where

import Partir.World.Scene (Scene (..))
import Partir.World.Types (Tick (..))

-- | A span of wall-clock time, in seconds.
newtype DeltaTime = DeltaTime Double
  deriving (Eq, Ord, Show)

-- | Simulation steps per second. Positive.
newtype TickRate = TickRate Double
  deriving (Eq, Ord, Show)

{- | Elapsed time not yet stepped, in ticks. 'accumulate' keeps it in
@[0, 1)@: the fraction of a step since the last one.
-}
newtype Backlog = Backlog Double
  deriving (Eq, Ord, Show)

-- | No elapsed time owed.
noBacklog :: Backlog
noBacklog = Backlog 0

{- | The most elapsed time one call to 'accumulate' counts. Without a cap, a
stall such as a suspended laptop replays every missed step at once, and a pass
slower than the time it simulates falls further behind each time. Dropping the
excess is safe because the server owns the canonical scene (ADR 0002).
-}
maxElapsed :: DeltaTime
maxElapsed = DeltaTime 0.25

{- | Add a slice of elapsed time to the backlog, returning the whole steps it
completes and the backlog left. Clamps the slice to @[0, 'maxElapsed']@.
-}
accumulate :: TickRate -> DeltaTime -> Backlog -> (Int, Backlog)
accumulate (TickRate rate) elapsed (Backlog owed) = (steps, Backlog (total - fromIntegral steps))
 where
  DeltaTime banked = max (DeltaTime 0) (min maxElapsed elapsed)
  total = owed + banked * rate
  steps = floor total

-- | Advance the scene by one fixed step: the tick moves, the entities don't.
step :: Scene -> Scene
step s = s{sceneTick = next (sceneTick s)}
 where
  next (Tick n) = Tick (n + 1)

-- | A reading of a monotonic clock, in seconds from any fixed origin.
newtype Instant = Instant Double
  deriving (Eq, Ord, Show)

-- | Where the loop reads wall-clock time and waits for it to pass.
data Clock = Clock
  { clockNow :: IO Instant
  , clockSleep :: DeltaTime -> IO ()
  -- ^ Wait at least the given span.
  }

{- | The scene the loop steps. Other threads may share it, so
'sceneStoreModify' applies a change atomically.
-}
newtype SceneStore = SceneStore
  { sceneStoreModify :: (Scene -> Scene) -> IO ()
  }

{- | Step the stored scene at the given rate, forever. Between passes it
sleeps until the next step is due.
-}
runLoop :: TickRate -> Clock -> SceneStore -> IO a
runLoop rate clock store = clockNow clock >>= go noBacklog
 where
  go owed before = do
    now <- clockNow clock
    let (steps, owed') = accumulate rate (since before now) owed
    sceneStoreModify store (applyTimes steps step)
    clockSleep clock (untilNextStep rate owed')
    go owed' now

since :: Instant -> Instant -> DeltaTime
since (Instant before) (Instant now) = DeltaTime (now - before)

untilNextStep :: TickRate -> Backlog -> DeltaTime
untilNextStep (TickRate hz) (Backlog fraction) = DeltaTime ((1 - fraction) / hz)

applyTimes :: Int -> (a -> a) -> a -> a
applyTimes n f x = iterate f x !! n
