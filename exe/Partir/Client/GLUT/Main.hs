-- SPDX-FileCopyrightText: 2020 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Main where

import Control.Exception (throwIO)
import Control.Monad (join)
import Data.StateVar (get, ($=))
import Debug.Trace (traceIO)
import qualified Graphics.UI.GLUT as GLUT
import Options.Applicative
import qualified Partir.Client.GLUT.Commands as Commands
import qualified Partir.Client.GLUT.Controls as Controls
import qualified Partir.Client.GLUT.Render as Render

import qualified Partir.Asset as Asset
import qualified Partir.Asset.GLTF as GLTF
import Paths_partir_qua_world (getDataFileName)

main :: IO ()
main = do
  (name, arguments) <- GLUT.getArgsAndInitialize
  traceIO $ unwords $ name : arguments

  GLUT.initialDisplayMode $= [GLUT.WithDepthBuffer, GLUT.DoubleBuffered, GLUT.RGBAMode]

  -- The profile the context is created with is fixed for its lifetime, and
  -- Partir.Client.GLUT.Render needs the core one.
  GLUT.initialContextVersion $= (3, 3)
  GLUT.initialContextProfile $= [GLUT.CoreProfile]

  _ <- GLUT.createWindow "Qua World"

  -- Uploading needs the context the window just created.
  renderer <- Render.upload =<< avatar

  -- Global Callbacks
  GLUT.menuStatusCallback $= Nothing
  GLUT.idleCallback $= Nothing

  -- Window Callbacks
  GLUT.displayCallback $= display renderer
  GLUT.overlayDisplayCallback $= Nothing
  GLUT.reshapeCallback $= Just (const (GLUT.postRedisplay Nothing))
  GLUT.positionCallback $= Nothing
  GLUT.windowStateCallback $= Nothing
  GLUT.closeCallback $= Nothing
  GLUT.keyboardMouseCallback $= Just Controls.primary
  GLUT.mouseWheelCallback $= Nothing
  GLUT.motionCallback $= Nothing
  GLUT.passiveMotionCallback $= Nothing

  commands arguments

  GLUT.mainLoop

{- | The only asset the client draws. A document that will not decode is
fatal: there is nothing else to put on screen.
-}
avatar :: IO Asset.Mesh
avatar = getDataFileName "examples/avatar.glb" >>= GLTF.loadAsset >>= either throwIO pure

display :: Render.Renderer -> GLUT.DisplayCallback
display renderer = do
  size <- get GLUT.windowSize
  Render.draw renderer size
  GLUT.swapBuffers

commands :: [String] -> IO ()
commands = join . handleParseResult . execParserPure defaultPrefs info'
 where
  info' = info (commands' <**> helper) (fullDesc <> progDesc "partir.qua.world")
  commands' = subparser (command "observe" Commands.observe)
