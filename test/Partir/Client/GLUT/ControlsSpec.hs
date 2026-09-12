module Partir.Client.GLUT.ControlsSpec (
  spec,
)
where

import qualified Graphics.UI.GLUT as GLUT
import Linear.V3 (V3 (..))
import Test.Hspec

import Partir.Agent.Input (Intent (..))
import Partir.Client.GLUT.Controls (intent)

spec :: Spec
spec =
  describe "intent" $ do
    it "asks to leave the world on escape" $
      pressing (GLUT.Char '\ESC') `shouldBe` Just Quit

    it "asks to move forward on w" $
      pressing (GLUT.Char 'w') `shouldBe` Just (Move (V3 0 0 (-1)))

    it "asks to move left on a" $
      pressing (GLUT.Char 'a') `shouldBe` Just (Move (V3 (-1) 0 0))

    it "asks to move back on s" $
      pressing (GLUT.Char 's') `shouldBe` Just (Move (V3 0 0 1))

    it "asks to move right on d" $
      pressing (GLUT.Char 'd') `shouldBe` Just (Move (V3 1 0 0))

    it "asks for nothing on a key it does not map" $
      pressing (GLUT.Char 'q') `shouldBe` Nothing

    it "asks for nothing when a mapped key comes back up" $
      releasing (GLUT.Char 'w') `shouldBe` Nothing

    it "asks for nothing on a mouse button" $
      pressing (GLUT.MouseButton GLUT.LeftButton) `shouldBe` Nothing

-- Helpers

pressing :: GLUT.Key -> Maybe Intent
pressing key = intent key GLUT.Down

releasing :: GLUT.Key -> Maybe Intent
releasing key = intent key GLUT.Up
