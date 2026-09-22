-- SPDX-FileCopyrightText: 2020 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Main where

import Control.Exception (Exception, throwIO)
import Control.Monad (join)
import Data.StateVar (get, ($=))
import Debug.Trace (traceIO)
import qualified Graphics.UI.GLUT as GLUT
import Options.Applicative
import qualified Partir.Client.GLUT.Commands as Commands
import qualified Partir.Client.GLUT.Controls as Controls
import qualified Partir.Client.GLUT.Render as Render

import qualified Partir.Asset as Asset
import qualified Partir.Asset.Animation as Animation
import qualified Partir.Asset.Animation.PNG as Sequence
import qualified Partir.Asset.GLTF as GLTF
import qualified Partir.Asset.OBJ as OBJ
import qualified Partir.Asset.Sprite as Sprite
import qualified Partir.Asset.Sprite.PNG as PNG
import qualified Partir.Asset.Tilemap as Tilemap
import qualified Partir.Asset.Tilemap.LDtk as LDtk
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
  renderer <- join (Render.upload <$> scene <*> icons)

  -- An animation advances on the clock, so something has to ask for a frame
  -- while no input arrives. A timer asks at a fixed cadence; the idle callback
  -- would ask as fast as the CPU allows.
  GLUT.addTimerCallback frameInterval animate

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

{- | Everything the client draws: the sample level's tiles, and the assets
standing on them.

The avatar's node places it at the origin, so the ground layer passes through
it.
-}
scene :: IO Asset.Mesh
scene = do
  level <- Tilemap.toMesh <$> bundled "examples/level.ldtk" LDtk.loadTilemap
  avatar <- bundled "examples/avatar.glb" GLTF.loadAsset
  pyramid <- bundled "examples/pyramid.obj" OBJ.loadAsset
  pure (Asset.Mesh (concatMap Asset.meshPrimitives [level, avatar, pyramid]))

{- | Read one of the package's own data files. A document that will not decode
is fatal here: the client ships it, so a failure is a broken build rather than
anything a player can act on.
-}
bundled :: Exception e => FilePath -> (FilePath -> IO (Either e a)) -> IO a
bundled name load = getDataFileName name >>= load >>= either throwIO pure

{- | The icons the client draws over the scene, left to right: a still frame
of the sprite sheet, then the walk cycle playing beside it.
-}
icons :: IO [Animation.Animation]
icons = do
  sheet <- bundled "examples/sprites.png" (PNG.loadSprite grid)
  walk <- bundled "examples/walk" (Sequence.loadAnimation rate)
  pure [Animation.still sheet, walk]
 where
  -- The cell examples/sprites.png is laid out on. A sheet carries no frame
  -- metadata, so this is knowledge about that file (#111).
  grid = Sprite.Grid{Sprite.gridFrameWidth = 16, Sprite.gridFrameHeight = 16}

  -- How fast examples/walk was drawn to play. A frame sequence carries no
  -- timing either, so this is knowledge about that directory (#118).
  rate = Animation.Rate{Animation.ratePerSecond = 8}

display :: Render.Renderer -> GLUT.DisplayCallback
display renderer = do
  size <- get GLUT.windowSize
  elapsed <- get GLUT.elapsedTime
  Render.draw renderer size (fromIntegral elapsed / 1000)
  GLUT.swapBuffers

-- | GLUT timers fire once, so each one has to schedule the next.
animate :: GLUT.TimerCallback
animate = do
  GLUT.postRedisplay Nothing
  GLUT.addTimerCallback frameInterval animate

-- | How long the client waits between frames, in milliseconds.
frameInterval :: GLUT.Timeout
frameInterval = 16

commands :: [String] -> IO ()
commands = join . handleParseResult . execParserPure defaultPrefs info'
 where
  info' = info (commands' <**> helper) (fullDesc <> progDesc "partir.qua.world")
  commands' = subparser (command "observe" Commands.observe)
