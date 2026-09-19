{-# OPTIONS_GHC -fno-warn-orphans #-}

module Partir.World.SceneSpec (
  test_empty,
  test_apply,
)
where

import Data.Text (pack)
import Linear.Quaternion (Quaternion (..))
import Linear.V3 (V3 (..))
import Test.QuickCheck (Arbitrary (arbitrary), Gen, oneof)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (testProperty)

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

-- The scene every `apply` example below starts from.
spawned :: Scene
spawned = apply (Spawn (Tick 1) anAgent anEntity here facing) empty

-- Generators

instance Arbitrary AgentId where
  arbitrary = AgentId <$> arbitrary

instance Arbitrary EntityId where
  arbitrary = EntityId <$> arbitrary

instance Arbitrary Tick where
  arbitrary = Tick <$> arbitrary

instance Arbitrary Event where
  arbitrary =
    oneof
      [ Spawn <$> arbitrary <*> arbitrary <*> arbitrary <*> genVec3 <*> genQuat
      , Despawn <$> arbitrary <*> arbitrary <*> arbitrary
      , Move <$> arbitrary <*> arbitrary <*> arbitrary <*> genVec3
      , Look <$> arbitrary <*> arbitrary <*> arbitrary <*> genQuat
      , Speak <$> arbitrary <*> arbitrary <*> (pack <$> arbitrary)
      , Interact <$> arbitrary <*> arbitrary <*> arbitrary
      ]

instance Arbitrary Scene where
  arbitrary = foldr apply empty <$> (arbitrary :: Gen [Event])

genVec3 :: Gen Vec3
genVec3 = V3 <$> arbitrary <*> arbitrary <*> arbitrary

genQuat :: Gen Quat
genQuat = Quaternion <$> arbitrary <*> genVec3
