module Partir.Agent.ObserverSpec (
  spec,
)
where

import Linear.Quaternion (Quaternion (..))
import Linear.V3 (V3 (..))
import Test.Hspec

import Partir.Agent.Class (step)
import Partir.Agent.Input (Intent)
import Partir.Agent.Observer (Observer (..))
import Partir.World.Event (Event (..))
import Partir.World.Scene (Scene, apply, empty)
import Partir.World.Types (AgentId (..), EntityId (..), Tick (..))

spec :: Spec
spec =
  describe "step" $ do
    it "emits no intents when there is nothing to see" $
      intentsFrom empty `shouldBe` []

    it "emits no intents when the scene holds entities" $
      intentsFrom populated `shouldBe` []

-- Fixtures

populated :: Scene
populated =
  apply
    (Spawn (Tick 1) (AgentId 7) (EntityId 42) (V3 1 2 3) (Quaternion 1 (V3 0 0 0)))
    empty

-- Helpers

intentsFrom :: Scene -> [Intent]
intentsFrom scene = snd (step scene Observer)
