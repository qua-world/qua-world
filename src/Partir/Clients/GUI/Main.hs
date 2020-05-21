module Main where

import           Data.StateVar                  ( ($=) )
import           Debug.Trace                    ( traceIO )
import qualified Graphics.UI.GLUT              as GLUT
import qualified Partir.Clients.GUI.Controls   as Controls

main :: IO ()
main = do
  (name, arguments) <- GLUT.getArgsAndInitialize
  traceIO $ unwords $ name : arguments

  GLUT.initialDisplayMode $= [GLUT.WithDepthBuffer, GLUT.DoubleBuffered, GLUT.RGBAMode]

  GLUT.createWindow "Qua World"
  GLUT.attachMenu GLUT.RightButton mainMenu -- TODO Change this to a contextual menu as GLUT expects.

  -- Global Callbacks
  GLUT.menuStatusCallback $= Nothing
  GLUT.idleCallback $= Nothing

  -- Window Callbacks
  GLUT.displayCallback $= display
  GLUT.overlayDisplayCallback $= Nothing
  GLUT.reshapeCallback $= Nothing
  GLUT.positionCallback $= Nothing
  GLUT.windowStateCallback $= Nothing
  GLUT.closeCallback $= Nothing
  GLUT.keyboardMouseCallback $= Just Controls.primary
  GLUT.mouseWheelCallback $= Nothing
  GLUT.motionCallback $= Nothing
  GLUT.passiveMotionCallback $= Nothing

  GLUT.mainLoop

mainMenu :: GLUT.Menu
mainMenu = GLUT.Menu [GLUT.MenuEntry "quit" Controls.quit]

display :: GLUT.DisplayCallback
display = do
  traceIO "starting display"
  GLUT.clear [GLUT.ColorBuffer, GLUT.DepthBuffer]
  GLUT.swapBuffers
  traceIO "stopping display"
