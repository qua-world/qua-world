-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Partir.Sim.LoopSpec (
  test_accumulate,
  test_step,
  test_runLoop,
)
where

import Control.Exception (Exception, throwIO, try)
import Data.IORef (IORef, modifyIORef', newIORef, readIORef, writeIORef)
import Data.List (mapAccumL)
import qualified Data.Map.Strict as Map
import Linear.Quaternion (Quaternion (..))
import Linear.V3 (V3 (..))
import Test.QuickCheck (
  Property,
  checkCoverage,
  choose,
  counterexample,
  cover,
  forAll,
  listOf,
 )
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (testProperty)

import Partir.Sim.Loop (
  Backlog (..),
  Clock (..),
  DeltaTime (..),
  SceneStore (..),
  TickRate (..),
  accumulate,
  maxElapsed,
  noBacklog,
  runLoop,
  step,
 )
import Partir.World.Scene (Scene (..), empty)
import Partir.World.Types (EntityId (..), Pose (..), Tick (..))

test_accumulate :: TestTree
test_accumulate =
  testGroup
    "accumulate"
    [ testCase "banks a slice too short for a step" $
        accumulate eightHz (DeltaTime 0.0625) noBacklog @?= (0, Backlog 0.5)
    , testCase "pays out the step a carried fraction completes" $
        accumulate eightHz (DeltaTime 0.0625) (Backlog 0.5) @?= (1, Backlog 0)
    , testCase "caps the time banked after a stall" $
        accumulate eightHz (DeltaTime 3600) noBacklog @?= (2, Backlog 0)
    , testCase "ignores a clock that runs backwards" $
        accumulate eightHz (DeltaTime (-1)) (Backlog 0.5) @?= (0, Backlog 0.5)
    , testProperty "steps track elapsed time however the slices fall" tracksElapsed
    ]

test_step :: TestTree
test_step =
  testGroup
    "step"
    [ testCase "advances the tick by one" $
        sceneTick (step scene) @?= Tick 8
    , testCase "leaves the entities in place" $
        sceneEntities (step scene) @?= sceneEntities scene
    ]

test_runLoop :: TestTree
test_runLoop =
  testGroup
    "runLoop"
    [ testCase "steps the stored scene once per tick elapsed" $ do
        (final, _) <- runScripted script
        sceneTick final @?= Tick 4
    , testCase "sleeps until the next step is due" $ do
        (_, sleeps) <- runScripted script
        sleeps @?= DeltaTime <$> [0.0625, 0.125, 0.09375, 0.125]
    ]

-- Properties

{- | Split a run of wall-clock time into uneven slices, and the steps paid out
plus the fraction still owed add back up to the time elapsed. The slices stay
under the cap, which would otherwise drop time on purpose.
-}
tracksElapsed :: Property
tracksElapsed =
  forAll (choose (10, 100)) $ \hz ->
    forAll (listOf (choose (0, cap))) $ \slices ->
      let rate = TickRate hz
          (Backlog owed, counts) = mapAccumL (\b dt -> swap (accumulate rate (DeltaTime dt) b)) noBacklog slices
          paid = fromIntegral (sum counts) + owed
          elapsed = sum slices * hz
       in checkCoverage
            . cover 10 (0 `elem` counts) "a slice too short to step"
            . cover 10 (any (> 1) counts) "a slice spanning several steps"
            . counterexample (show (paid, elapsed))
            $ abs (paid - elapsed) < 1e-9 && owed >= 0 && owed < 1
 where
  DeltaTime cap = maxElapsed
  swap (a, b) = (b, a)

-- Fixtures

-- A rate whose period, an eighth of a second, and its fractions are exact in
-- binary, so the examples compare without slack.
eightHz :: TickRate
eightHz = TickRate 8

scene :: Scene
scene =
  Scene
    { sceneTick = Tick 7
    , sceneEntities = Map.singleton (EntityId 1) (Pose (V3 1 2 3) (Quaternion 1 (V3 0 0 0)))
    }

{- | Clock readings, in seconds. At 'eightHz' the slices between them are half,
one and a half, a quarter, and one and three quarters ticks long: four whole
ticks over half a second, with a fraction carried between slices.
-}
script :: [Double]
script = [0, 0.0625, 0.25, 0.28125, 0.5]

-- Helpers

-- Raised when the scripted clock has no reading left, to end 'runLoop'.
data ScriptEnded = ScriptEnded
  deriving Show

instance Exception ScriptEnded

-- Run the loop at 'eightHz' until the clock's script runs out, returning the
-- stored scene and every span the loop slept.
runScripted :: [Double] -> IO (Scene, [DeltaTime])
runScripted readings = do
  remaining <- newIORef readings
  sleeps <- newIORef []
  stored <- newIORef empty
  _ <- try (runLoop eightHz (scriptedClock remaining sleeps) (refStore stored)) :: IO (Either ScriptEnded ())
  (,) <$> readIORef stored <*> (reverse <$> readIORef sleeps)

scriptedClock :: IORef [Double] -> IORef [DeltaTime] -> Clock
scriptedClock remaining sleeps =
  Clock
    { clockNow = readIORef remaining >>= next
    , clockSleep = \dt -> modifyIORef' sleeps (dt :)
    }
 where
  next [] = throwIO ScriptEnded
  next (t : ts) = t <$ writeIORef remaining ts

refStore :: IORef Scene -> SceneStore
refStore ref = SceneStore (modifyIORef' ref)
