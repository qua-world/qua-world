-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Partir.World.SceneSpec (
  test_empty,
  test_apply,
  test_model,
)
where

import Data.List (foldl', nub)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (pack)
import Linear.Quaternion (Quaternion (..))
import Linear.V3 (V3 (..))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (testProperty)

import Partir.Arbitrary ()

import Partir.World.Event (Event (..), eventTick)
import Partir.World.Scene (
  Scene (..),
  apply,
  empty,
  entityAt,
 )
import Partir.World.Types (
  AgentId (..),
  EntityId (..),
  Pose (..),
  Quat,
  Tick (..),
  Vec3,
 )

test_empty :: TestTree
test_empty =
  testGroup
    "empty"
    [ testCase "starts at tick zero with no entities" $ do
        sceneTick empty @?= Tick 0
        entityAt anEntity empty @?= Nothing
    ]

test_apply :: TestTree
test_apply =
  testGroup
    "apply"
    [ testCase "spawns an entity at its position and orientation" $
        entityAt anEntity spawned
          @?= Just (Pose here facing)
    , testCase "despawns a previously spawned entity" $
        entityAt anEntity (apply (Despawn (Tick 2) anAgent anEntity) spawned)
          @?= Nothing
    , testCase "moves a spawned entity, leaving its orientation" $
        entityAt anEntity (apply (Move (Tick 2) anAgent anEntity there) spawned)
          @?= Just (Pose there facing)
    , testCase "reorients a spawned entity, leaving its position" $
        entityAt anEntity (apply (Look (Tick 2) anAgent anEntity turned) spawned)
          @?= Just (Pose here turned)
    , testCase "ignores moves that target an absent entity" $
        sceneEntities (apply (Move (Tick 1) anAgent anEntity there) empty)
          @?= sceneEntities empty
    , testCase "leaves entities untouched for Speak and Interact" $ do
        sceneEntities (apply (Speak (Tick 1) anAgent (pack "hi")) spawned)
          @?= sceneEntities spawned
        sceneEntities (apply (Interact (Tick 1) anAgent anEntity) spawned)
          @?= sceneEntities spawned
    , testProperty "never decreases the scene tick" $ \event scene ->
        sceneTick (apply event scene) >= sceneTick scene
    , testProperty "advances the tick to the max of the scene and event" $ \event scene ->
        sceneTick (apply event scene) == max (sceneTick scene) (eventTick event)
    ]

{- | The scene folded forward one event at a time, against each entity's pose
read off its own events alone.

`apply` carries the whole scene through every event; `entityHistory` replays
one entity and ignores the rest. Agreement is what says an event touches only
its subject and leaves nothing behind for the next one — the guarantee
`Partir.Sim.Prediction` (#17) and `Partir.Sim.Reconcile` (#19) rest on when
they replay a command buffer after a correction. Those modules will want the
same shape against a richer model: a command sequence, a reference
implementation, and a comparison after each step.
-}
test_model :: TestTree
test_model =
  testGroup
    "against a model"
    [ testProperty "holds the pose each entity's own events imply" $ \events ->
        sceneEntities (foldl' (flip apply) empty events) == model events
    ]

-- Model

model :: [Event] -> Map EntityId Pose
model events =
  Map.fromList
    [ (eid, pose)
    | eid <- nub (concatMap subject events)
    , Just pose <- [entityHistory eid events]
    ]

-- The entity an event acts on. `Speak` addresses the world, not an entity.
subject :: Event -> [EntityId]
subject (Spawn _ _ eid _ _) = [eid]
subject (Despawn _ _ eid) = [eid]
subject (Move _ _ eid _) = [eid]
subject (Look _ _ eid _) = [eid]
subject Speak{} = []
subject (Interact _ _ eid) = [eid]

-- Where one entity ends up, reading only the events naming it.
entityHistory :: EntityId -> [Event] -> Maybe Pose
entityHistory eid = foldl' step Nothing . filter ((== [eid]) . subject)
 where
  step _ (Spawn _ _ _ p q) = Just (Pose p q)
  step _ Despawn{} = Nothing
  step acc (Move _ _ _ p) = fmap (\pose -> pose{posePosition = p}) acc
  step acc (Look _ _ _ q) = fmap (\pose -> pose{poseOrientation = q}) acc
  step acc _ = acc

-- Fixtures

anAgent :: AgentId
anAgent = AgentId 7

anEntity :: EntityId
anEntity = EntityId 42

here :: Vec3
here = V3 1 2 3

there :: Vec3
there = V3 4 5 6

facing :: Quat
facing = Quaternion 1 (V3 0 0 0)

turned :: Quat
turned = Quaternion 0 (V3 0 1 0)

spawned :: Scene
spawned = apply (Spawn (Tick 1) anAgent anEntity here facing) empty
