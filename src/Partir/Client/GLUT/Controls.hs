module Partir.Client.GLUT.Controls (
  -- * Primary Callback
  primary,

  -- * Controls
  quit,
)
where

import Data.Maybe (fromJust)
import Data.StateVar (get)
import Debug.Trace (traceIO)
import qualified Graphics.UI.GLUT as GLUT
import System.Exit (exitSuccess)

primary :: GLUT.KeyboardMouseCallback
primary (GLUT.Char '\ESC') _keyState _modifiers _position = quit
primary key keyState modifiers position = do
  traceIO "starting primary controls"
  traceIO $ "key: " ++ show key
  traceIO $ "keyState: " ++ show keyState
  traceIO $ "modifiers: " ++ show modifiers
  traceIO $ "position: " ++ show position
  traceIO "stopping primary controls"

quit :: IO ()
quit = do
  traceIO "quitting ..."
  window <- fromJust <$> get GLUT.currentWindow
  GLUT.destroyWindow window
  exitSuccess
