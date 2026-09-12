{- |
Module      : Partir.Client.GLUT.Controls
Description : Adapts GLUT input events into the intents every agent speaks
Copyright   : (c) Alex Brandt, 2026
License     : MIT

The GUI player takes part in the world the same way a bot does: it emits
'Partir.Agent.Input.Intent's. This module is the adapter that turns GLUT's
keyboard and mouse events into them, so the layers below never learn which
toolkit produced an input.

'intent' is pure, which is what lets the mapping be tested without a window.
'primary' is the GLUT callback that pairs it with the effect each intent has.
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

-- | Routes every keyboard and mouse event through the intent vocabulary.
primary :: GLUT.KeyboardMouseCallback
primary key keyState _modifiers _position =
  maybe (pure ()) perform (intent key keyState)

{- | What the player asked for, if the event asks for anything. Movement keys
map to a unit direction in the right-handed basis GLUT hands the client, with
@-Z@ forward. #94 settles whether that vector is an absolute position or a
displacement; only its direction is claimed here.
-}
intent :: GLUT.Key -> GLUT.KeyState -> Maybe Intent
intent (GLUT.Char '\ESC') GLUT.Down = Just Quit
intent (GLUT.Char 'w') GLUT.Down = Just (Move (V3 0 0 (-1)))
intent (GLUT.Char 'a') GLUT.Down = Just (Move (V3 (-1) 0 0))
intent (GLUT.Char 's') GLUT.Down = Just (Move (V3 0 0 1))
intent (GLUT.Char 'd') GLUT.Down = Just (Move (V3 1 0 0))
intent _ _ = Nothing

{- | Carries out an intent the player emitted. Only 'Quit' has an effect the
client can give it today; the rest wait on a camera to move and a server to
send to.
-}
perform :: Intent -> IO ()
perform Quit = quit
perform i = traceIO $ "unhandled intent: " ++ show i

quit :: IO ()
quit = do
  traceIO "quitting ..."
  window <- fromJust <$> get GLUT.currentWindow
  GLUT.destroyWindow window
  exitSuccess
