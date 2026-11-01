-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Sim.Loop
Description : Step the predicted scene at a fixed rate, apart from rendering

The client steps its predicted 'Scene' at a fixed 'TickRate', whatever rate
the renderer draws at. Coupling the two makes motion depend on the framerate,
lets fast movers skip past collisions, and turns frame jitter into simulation
jitter (Lopes, "The Basics"; Fiedler, "Fix Your Timestep!").

Wall-clock time arrives in uneven slices. 'accumulate' banks each slice in a
'Backlog' and pays it out as whole steps, carrying the fraction left over, so
the number of steps tracks elapsed time however the slices fall. 'runLoop'
drives that from a 'Clock' and writes each step through a 'SceneStore'; it
knows nothing of windows or sockets.
-}
module Partir.Sim.Loop (
  DeltaTime (..),
  TickRate (..),
  Backlog (..),
  noBacklog,
  maxElapsed,
  accumulate,
  step,
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

-- | How many simulation steps run per second of wall-clock time. Positive.
newtype TickRate = TickRate Double
  deriving (Eq, Ord, Show)

{- | Elapsed time not yet paid out as a step, in ticks. 'accumulate' keeps it
in @[0, 1)@, so it doubles as how far the scene sits between one step and the
next.
-}
newtype Backlog = Backlog Double
  deriving (Eq, Ord, Show)

-- | Nothing owed: the scene is exactly at a step.
noBacklog :: Backlog
noBacklog = Backlog 0

{- | The most wall-clock time one call to 'accumulate' banks. After a stall
(a suspended laptop, a debugger pause) the loop would otherwise run every
missed step at once, and a frame that takes longer than the time it simulates
falls further behind on each pass. The time above the cap is dropped; the
server's canonical scene corrects the drift.
-}
maxElapsed :: DeltaTime
maxElapsed = DeltaTime 0.25

{- | Bank a slice of elapsed time and pay out the whole steps it completes.
The slice is clamped to @[0, 'maxElapsed']@.
-}
accumulate :: TickRate -> DeltaTime -> Backlog -> (Int, Backlog)
accumulate (TickRate rate) elapsed (Backlog owed) = (steps, Backlog (total - fromIntegral steps))
 where
  DeltaTime banked = max (DeltaTime 0) (min maxElapsed elapsed)
  total = owed + banked * rate
  steps = floor total

{- | Advance the scene by one fixed step. Only the clock moves until local
prediction (#17) acts on the scene's entities.
-}
step :: Scene -> Scene
step s = s{sceneTick = next (sceneTick s)}
 where
  next (Tick n) = Tick (n + 1)

-- | Where the loop reads wall-clock time and waits for it to pass.
data Clock = Clock
  { clockNow :: IO Double
  -- ^ Seconds on a monotonic clock, from any fixed origin.
  , clockSleep :: DeltaTime -> IO ()
  -- ^ Wait at least the given span.
  }

{- | The scene the loop steps. The network session and the renderer share it,
so a change applies atomically rather than as a read followed by a write.
-}
newtype SceneStore = SceneStore
  { sceneStoreModify :: (Scene -> Scene) -> IO ()
  }

{- | Step the stored scene at the given rate, forever. Between passes it
sleeps until the next step is due.
-}
runLoop :: TickRate -> Clock -> SceneStore -> IO a
runLoop rate@(TickRate hz) clock store = clockNow clock >>= go noBacklog
 where
  go owed before = do
    now <- clockNow clock
    let (steps, owed'@(Backlog fraction)) = accumulate rate (DeltaTime (now - before)) owed
    sceneStoreModify store (applyTimes steps step)
    clockSleep clock (DeltaTime ((1 - fraction) / hz))
    go owed' now

applyTimes :: Int -> (a -> a) -> a -> a
applyTimes n f x = iterate f x !! n
