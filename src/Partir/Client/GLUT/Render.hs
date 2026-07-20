{-|
Module      : Partir.Client.GLUT.Render
Description : Draw a loaded 'Mesh' through the fixed-function GLUT pipeline
Copyright   : (c) Alex Brandt, 2026
License     : MIT

The minimum needed to see 3D content on screen: a perspective projection sized
to the window, a fixed camera looking at the origin, and an immediate-mode
triangle draw of every primitive. Deliberately fixed-function and unlit — enough
to confirm an asset loads and renders before richer shading lands.
-}
module Partir.Client.GLUT.Render
  ( reshape
  , render
  )
where

import qualified Data.Vector as Vector
import Graphics.Rendering.OpenGL (($=))
import qualified Graphics.Rendering.OpenGL as GL
import qualified Graphics.Rendering.OpenGL.GLU as GLU
import Linear.V3 (V3 (..))

import Partir.Asset (Mesh (..), Primitive (..))

-- | Keep the projection matched to the window: full-window viewport and a
-- perspective frustum whose aspect ratio tracks the current size.
reshape :: GL.Size -> IO ()
reshape size@(GL.Size w h) = do
  GL.viewport $= (GL.Position 0 0, size)
  GL.matrixMode $= GL.Projection
  GL.loadIdentity
  GLU.perspective 45 (fromIntegral w / fromIntegral (max 1 h)) 0.1 100
  GL.matrixMode $= GL.Modelview 0

-- | Clear, aim the camera at the origin, and draw the mesh in front of it.
-- The caller is responsible for presenting the frame (buffer swap).
render :: Mesh -> IO ()
render mesh = do
  GL.clear [GL.ColorBuffer, GL.DepthBuffer]
  GL.matrixMode $= GL.Modelview 0
  GL.loadIdentity
  GLU.lookAt (GL.Vertex3 0 0 3) (GL.Vertex3 0 0 0) (GL.Vector3 0 1 0)
  GL.color (GL.Color3 (0.6 :: GL.GLfloat) 0.7 0.9)
  mapM_ drawPrimitive (meshPrimitives mesh)

drawPrimitive :: Primitive -> IO ()
drawPrimitive prim =
  GL.renderPrimitive GL.Triangles $
    mapM_ emit (drawOrder prim)
 where
  positions = primitivePositions prim
  drawOrder p
    | Vector.null (primitiveIndices p) = [0 .. Vector.length positions - 1]
    | otherwise = map fromIntegral (Vector.toList (primitiveIndices p))
  emit i =
    let V3 x y z = positions Vector.! i
     in GL.vertex (GL.Vertex3 x y z)
