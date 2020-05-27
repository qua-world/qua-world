module Main where

import           Control.Monad                  ( join )
import           Data.StateVar                  ( ($=) )
import           Debug.Trace                    ( traceIO )
import qualified Graphics.UI.GLUT              as GLUT
import           Options.Applicative
import qualified Partir.Client.GLUT.Controls   as Controls
import qualified Partir.Client.GLUT.Commands   as Commands

main :: IO ()
main = do
  (name, arguments) <- GLUT.getArgsAndInitialize
  traceIO $ unwords $ name : arguments

  GLUT.initialDisplayMode $= [GLUT.WithDepthBuffer, GLUT.DoubleBuffered, GLUT.RGBAMode]

  GLUT.createWindow "Qua World"

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

  commands arguments

  GLUT.mainLoop

display :: GLUT.DisplayCallback
display = do
  traceIO "starting display"
  GLUT.clear [GLUT.ColorBuffer, GLUT.DepthBuffer]
  GLUT.swapBuffers
  traceIO "stopping display"

commands :: [String] -> IO ()
commands = join . handleParseResult . execParserPure defaultPrefs info'
 where
  info'     = info (commands' <**> helper) (fullDesc <> progDesc "partir.qua.world")
  commands' = subparser (command "observe" Commands.observe)
