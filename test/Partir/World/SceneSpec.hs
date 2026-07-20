{-# OPTIONS_GHC -fno-warn-orphans #-}

module Partir.World.SceneSpec
  ( spec
  )
where

import Data.Text (pack)
import Linear.Quaternion (Quaternion (..))
import Linear.V3 (V3 (..))
import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck (Arbitrary (arbitrary), Gen, oneof)

import Partir.World.Event (Event (..), eventTick)
import Partir.World.Scene
  ( Scene (..)
  , apply
  , empty
  , entityAt
  )
import Partir.World.Types
  ( AgentId (..)
  , EntityId (..)
  , Pose (..)
  , Quat
  , Tick (..)
  , Vec3
  )

spec :: Spec
spec = do
  describe "empty" $
    it "starts at tick zero with no entities" $ do
      sceneTick empty `shouldBe` Tick 0
      entityAt anEntity empty `shouldBe` Nothing

  describe "apply" $ do
    it "spawns an entity at its position and orientation" $
      entityAt anEntity (spawned empty)
        `shouldBe` Just (Pose here facing)

    it "despawns a previously spawned entity" $
      entityAt anEntity (apply (Despawn (Tick 2) anAgent anEntity) (spawned empty))
        `shouldBe` Nothing

    it "moves a spawned entity, leaving its orientation" $
      entityAt anEntity (apply (Move (Tick 2) anAgent anEntity there) (spawned empty))
        `shouldBe` Just (Pose there facing)

    it "reorients a spawned entity, leaving its position" $
      entityAt anEntity (apply (Look (Tick 2) anAgent anEntity turned) (spawned empty))
        `shouldBe` Just (Pose here turned)

    it "ignores moves that target an absent entity" $
      sceneEntities (apply (Move (Tick 1) anAgent anEntity there) empty)
        `shouldBe` sceneEntities empty

    it "leaves entities untouched for Speak and Interact" $ do
      sceneEntities (apply (Speak (Tick 1) anAgent (pack "hi")) (spawned empty))
        `shouldBe` sceneEntities (spawned empty)
      sceneEntities (apply (Interact (Tick 1) anAgent anEntity) (spawned empty))
        `shouldBe` sceneEntities (spawned empty)

    prop "never decreases the scene tick" $ \event scene ->
      sceneTick (apply event scene) >= sceneTick scene

    prop "advances the tick to the max of the scene and event" $ \event scene ->
      sceneTick (apply event scene) == max (sceneTick scene) (eventTick event)

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

spawned :: Scene -> Scene
spawned = apply (Spawn (Tick 1) anAgent anEntity here facing)

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
