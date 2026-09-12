{- |
Module      : Partir.Client.GLUT.Controls
Description : Maps GLUT input events to agent intents
Copyright   : (c) Alex Brandt, 2026
License     : MIT

GLUT delivers keys and mouse buttons; the rest of the client speaks
'Partir.Agent.Input.Intent'. This module translates between them.

Deciding is kept apart from acting so the mapping can be tested without a
window: 'intent' decides, 'primary' acts.
-}
module Partir.Client.GLUT.Controls (
  -- * Primary Callback
  primary,

  -- * Intent Mapping
  intent,
)
where

import Data.Maybe (fromJust)
import Data.StateVar (get)
import Debug.Trace (traceIO)
import qualified Graphics.UI.GLUT as GLUT
import Linear.V3 (V3 (..))
import System.Exit (exitSuccess)

import Partir.Agent.Input (Intent (..))
import Partir.World.Types (Vec3)

-- | An event that maps to no intent does nothing.
primary :: GLUT.KeyboardMouseCallback
primary key keyState _modifiers _position =
  maybe (pure ()) perform (intent key keyState)

{- | What the player asked for, if the event asks for anything. #94 settles
whether a movement vector is an absolute position or a displacement; only its
direction is claimed here.
-}
intent :: GLUT.Key -> GLUT.KeyState -> Maybe Intent
intent (GLUT.Char '\ESC') GLUT.Down = Just Quit
intent (GLUT.Char 'w') GLUT.Down = Just (Move forward)
intent (GLUT.Char 'a') GLUT.Down = Just (Move left)
intent (GLUT.Char 's') GLUT.Down = Just (Move back)
intent (GLUT.Char 'd') GLUT.Down = Just (Move right)
intent _ _ = Nothing

{- | Unit directions in the client's right-handed basis: @-Z@ ahead of the
player, @+X@ to their right.
-}
forward, left, back, right :: Vec3
forward = V3 0 0 (-1)
left = V3 (-1) 0 0
back = V3 0 0 1
right = V3 1 0 0

-- | Only 'Quit' can take effect: nothing the other intents reach exists yet.
perform :: Intent -> IO ()
perform Quit = quit
perform i = traceIO $ "unhandled intent: " ++ show i

quit :: IO ()
quit = do
  traceIO "quitting ..."
  window <- fromJust <$> get GLUT.currentWindow
  GLUT.destroyWindow window
  exitSuccess
