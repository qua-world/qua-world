-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Client.GLUT.View
Description : What the renderer draws and how it is framed, decided without a context

What "Partir.Client.GLUT.Render" settles before it issues an OpenGL call:
where the client watches the world from, and how many elements a primitive
draws. None of it needs a live context, so the test suite reaches all of it.
-}
module Partir.Client.GLUT.View (
  camera,
  elementCount,
  overlayBounds,
  frameBounds,
)
where

import qualified Data.Vector as Vector
import qualified Graphics.Rendering.OpenGL as GL
import Linear.Matrix (M44, (!*!))
import Linear.Projection (lookAt, perspective)
import Linear.V3 (V3 (..))
import Linear.V4 (V4 (..))

import Partir.Asset (Frame (..), Primitive (..), Sprite (..))

{- | The transform from model space to clip space, for a window of the given
size: a fixed viewpoint, and a projection matched to the window's aspect
ratio.
-}
camera :: GL.Size -> M44 Float
camera (GL.Size width height) =
  perspective verticalFieldOfView aspect nearPlane farPlane !*! lookAt eye target up
 where
  aspect = fromIntegral width / fromIntegral (max 1 height)

{- | Where the client watches the world from. Off all three axes, so an asset
reads as a solid rather than as a flat silhouette.
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

{- | Where the sprite overlay sits in clip space, as left, top, right, bottom —
the order the vertex shader reads the pair of corners from.

The icon holds a square footprint in pixels whatever shape the window is, so
its extent follows from the window size rather than being fixed in clip space,
where one unit spans a different number of pixels along each axis.
-}
overlayBounds :: GL.Size -> V4 Float
overlayBounds (GL.Size width height) =
  V4 left top (left + 2 * overlaySize / w) (top - 2 * overlaySize / h)
 where
  left = -1 + 2 * overlayMargin / w
  top = 1 - 2 * overlayMargin / h
  w = fromIntegral (max 1 width)
  h = fromIntegral (max 1 height)

-- | The icon's footprint and its inset from the window's top-left, in pixels.
overlaySize, overlayMargin :: Float
overlaySize = 96
overlayMargin = 16

{- | Where one frame sits in its sheet's texture coordinates, in the same
left\/top\/right\/bottom order as 'overlayBounds'.

The sheet uploads with its top row first, so the vertical coordinate runs down
the image and a frame's 'frameY' stays its top edge.
-}
frameBounds :: Sprite -> Frame -> V4 Float
frameBounds sprite frame =
  V4
    (fromIntegral (frameX frame) / w)
    (fromIntegral (frameY frame) / h)
    (fromIntegral (frameX frame + frameWidth frame) / w)
    (fromIntegral (frameY frame + frameHeight frame) / h)
 where
  w = fromIntegral (max 1 (spriteWidth sprite))
  h = fromIntegral (max 1 (spriteHeight sprite))

{- | How many elements one draw call issues: the indices when the primitive
has them, otherwise its vertices.
-}
elementCount :: Primitive -> GL.GLsizei
elementCount prim
  | Vector.null indices = fromIntegral (Vector.length (primitivePositions prim))
  | otherwise = fromIntegral (Vector.length indices)
 where
  indices = primitiveIndices prim
