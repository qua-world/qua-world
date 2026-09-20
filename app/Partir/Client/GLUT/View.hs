-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Client.GLUT.View
Description : What the renderer draws and how it is framed, decided without a context

The decisions "Partir.Client.GLUT.Render" makes before it issues a single
OpenGL call: where the client watches the world from, and how many elements a
primitive draws. Separated because none of it needs a live context, so all of
it is checkable in the test suite, which "Partir.Client.GLUT.Render" is not.

OpenGL types appear here as the vocabulary the renderer speaks. Naming them
binds no context.
-}
module Partir.Client.GLUT.View (
  camera,
  elementCount,
)
where

import qualified Data.Vector as Vector
import qualified Graphics.Rendering.OpenGL as GL
import Linear.Matrix (M44, (!*!))
import Linear.Projection (lookAt, perspective)
import Linear.V3 (V3 (..))

import Partir.Asset (Primitive (..))

{- | The transform from model space to clip space, for a window of the given
size: a fixed viewpoint, and a projection matched to the window's aspect
ratio.
-}
camera :: GL.Size -> M44 Float
camera (GL.Size width height) =
  perspective verticalFieldOfView aspect nearPlane farPlane !*! lookAt eye target up
 where
  aspect = fromIntegral width / fromIntegral (max 1 height)

{- | Where the client watches the world from. The viewpoint sits off all three
axes so an asset reads as a solid rather than as its own silhouette.
-}
eye, target, up :: V3 Float
eye = V3 2.2 1.6 2.6
target = V3 0 0 0
up = V3 0 1 0

-- | The visible depth range, and how much of the world fits across it.
verticalFieldOfView, nearPlane, farPlane :: Float
verticalFieldOfView = pi / 4
nearPlane = 0.1
farPlane = 100

{- | How many elements one draw call issues: the indices when the primitive
has them, otherwise its vertices.
-}
elementCount :: Primitive -> GL.GLsizei
elementCount prim
  | Vector.null indices = fromIntegral (Vector.length (primitivePositions prim))
  | otherwise = fromIntegral (Vector.length indices)
 where
  indices = primitiveIndices prim
