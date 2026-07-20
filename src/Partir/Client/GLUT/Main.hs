module Main where

import           Control.Monad                  ( join )
import           Data.StateVar                  ( ($=) )
import           Debug.Trace                    ( traceIO )
import qualified Graphics.UI.GLUT              as GLUT
import           Options.Applicative
import qualified Partir.Asset                 as Asset
import qualified Partir.Asset.GLTF             as GLTF
import qualified Partir.Client.GLUT.Controls   as Controls
import qualified Partir.Client.GLUT.Commands   as Commands
import qualified Partir.Client.GLUT.Render     as Render

main :: IO ()
main = do
  (name, arguments) <- GLUT.getArgsAndInitialize
  traceIO $ unwords $ name : arguments

  GLUT.initialDisplayMode $= [GLUT.WithDepthBuffer, GLUT.DoubleBuffered, GLUT.RGBAMode]
  GLUT.initialWindowSize $= GLUT.Size 800 600

  _ <- GLUT.createWindow "Qua World"

  GLUT.depthFunc $= Just GLUT.Less

  mesh <- GLTF.loadAsset "examples/avatar.glb"

  -- Global Callbacks
  GLUT.menuStatusCallback $= Nothing
  GLUT.idleCallback $= Nothing

  -- Window Callbacks
  GLUT.displayCallback $= display mesh
  GLUT.overlayDisplayCallback $= Nothing
  GLUT.reshapeCallback $= Just Render.reshape
  GLUT.positionCallback $= Nothing
  GLUT.windowStateCallback $= Nothing
  GLUT.closeCallback $= Nothing
  GLUT.keyboardMouseCallback $= Just Controls.primary
  GLUT.mouseWheelCallback $= Nothing
  GLUT.motionCallback $= Nothing
  GLUT.passiveMotionCallback $= Nothing

  commands arguments

  GLUT.mainLoop

display :: Asset.Mesh -> GLUT.DisplayCallback
display mesh = do
  Render.render mesh
  GLUT.swapBuffers

commands :: [String] -> IO ()
commands = join . handleParseResult . execParserPure defaultPrefs info'
 where
  info'     = info (commands' <**> helper) (fullDesc <> progDesc "partir.qua.world")
  commands' = subparser (command "observe" Commands.observe)
