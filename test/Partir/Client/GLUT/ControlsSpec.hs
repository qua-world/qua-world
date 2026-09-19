-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Partir.Client.GLUT.ControlsSpec (
  test_intent,
)
where

import qualified Graphics.UI.GLUT as GLUT
import Linear.V3 (V3 (..))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

import Partir.Agent.Input (Intent (..))
import Partir.Client.GLUT.Controls (intent)

test_intent :: TestTree
test_intent =
  testGroup
    "intent"
    [ testCase "asks to leave the world on escape" $
        pressing (GLUT.Char '\ESC') @?= Just Quit
    , testCase "asks to move forward on w" $
        pressing (GLUT.Char 'w') @?= Just (Move (V3 0 0 (-1)))
    , testCase "asks to move left on a" $
        pressing (GLUT.Char 'a') @?= Just (Move (V3 (-1) 0 0))
    , testCase "asks to move back on s" $
        pressing (GLUT.Char 's') @?= Just (Move (V3 0 0 1))
    , testCase "asks to move right on d" $
        pressing (GLUT.Char 'd') @?= Just (Move (V3 1 0 0))
    , testCase "asks for nothing on a key it does not map" $
        pressing (GLUT.Char 'q') @?= Nothing
    , testCase "asks for nothing when a mapped key comes back up" $
        releasing (GLUT.Char 'w') @?= Nothing
    , testCase "asks for nothing on a mouse button" $
        pressing (GLUT.MouseButton GLUT.LeftButton) @?= Nothing
    ]

-- Helpers

pressing :: GLUT.Key -> Maybe Intent
pressing key = intent key GLUT.Down

releasing :: GLUT.Key -> Maybe Intent
releasing key = intent key GLUT.Up
