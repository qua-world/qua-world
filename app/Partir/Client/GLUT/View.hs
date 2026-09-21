-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Client.GLUT.View
Description : What the renderer draws and how it is framed, decided without a context

What "Partir.Client.GLUT.Render" settles before it issues an OpenGL call:
where the client watches the world from, how many elements a primitive draws,
where an overlay sits, and which frame of its animation is showing. None of it
needs a live context, so the test suite reaches all of it.
-}
module Partir.Client.GLUT.View (
  Bounds (..),
  Icon,
  camera,
  elementCount,
  icon,
  iconAt,
  overlayBounds,
  frameBounds,
)
where

import Data.Vector (Vector)
import qualified Data.Vector as Vector
import qualified Graphics.Rendering.OpenGL as GL
import Linear.Matrix (M44, (!*!))
import Linear.Projection (lookAt, perspective)
import Linear.V3 (V3 (..))

import Partir.Asset (Primitive (..))
import Partir.Asset.Animation (Animation (..), stepAt, timeline)
import Partir.Asset.Sprite (Frame (..), Sprite (..))

{- | An axis-aligned rectangle, given by its edges.

The icon's place on screen and a frame's place in its sheet are both this
shape. Both reach the vertex shader as one @vec4@ it interpolates a corner
between: @(left, top)@ in @xy@, @(right, bottom)@ in @zw@.
-}
data Bounds = Bounds
  { boundsLeft :: Float
  , boundsTop :: Float
  , boundsRight :: Float
  , boundsBottom :: Float
  }
  deriving (Eq, Show)

{- | The transform from model space to clip space, for a window of the given
size: a fixed viewpoint, and a projection matched to the window's aspect
ratio.
-}
camera :: GL.Size -> M44 Float
camera (GL.Size width height) =
  perspective verticalFieldOfView aspect nearPlane farPlane !*! lookAt eye target up
 where
  aspect = fromIntegral width / divisor height

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

{- | An animation reduced to what drawing it repeatedly needs: how long each
frame holds, and where each one sits in its sheet.

The sheet's pixels are not part of it. A renderer that has uploaded them as a
texture holds an 'Icon' and no 'Sprite'.
-}
data Icon = Icon
  { iconDurations :: Vector Double
  , iconFrames :: Vector Bounds
  }

-- | Reduce an animation once, before drawing it every frame.
icon :: Animation -> Icon
icon animation =
  Icon
    { iconDurations = Vector.map fst steps
    , iconFrames = Vector.map (frameBounds (animationSheet animation) . snd) steps
    }
 where
  steps = timeline animation

{- | Where the art an icon shows after the given seconds sits in its sheet.
'Nothing' when the animation has no frame to show, and the caller then draws
nothing at all rather than drawing something arbitrary.
-}
iconAt :: Icon -> Double -> Maybe Bounds
iconAt shown elapsed =
  stepAt (iconDurations shown) elapsed >>= (iconFrames shown Vector.!?)

{- | Where the overlay in the given slot sits in clip space. Slots run left to
right from the window's top-left corner, one icon each.

An icon holds a square footprint in pixels whatever shape the window is. Its
extent therefore follows from the window size: one clip-space unit spans a
different number of pixels along each axis.
-}
overlayBounds :: GL.Size -> Int -> Bounds
overlayBounds (GL.Size width height) slot =
  Bounds
    { boundsLeft = left
    , boundsTop = top
    , boundsRight = left + 2 * overlaySize / w
    , boundsBottom = top - 2 * overlaySize / h
    }
 where
  left = -1 + 2 * (overlayMargin + fromIntegral slot * (overlaySize + overlayMargin)) / w
  top = 1 - 2 * overlayMargin / h
  w = divisor width
  h = divisor height

{- | An icon's footprint, and the gap holding it off the window's top-left
corner and off the icon before it.
-}
overlaySize, overlayMargin :: Float
overlaySize = 96
overlayMargin = 16

{- | Where one frame sits in its sheet's texture coordinates.

The sheet uploads with its top row first, so the vertical coordinate runs down
the image and a frame's 'frameY' stays its top edge.
-}
frameBounds :: Sprite -> Frame -> Bounds
frameBounds sprite frame =
  Bounds
    { boundsLeft = fromIntegral (frameX frame) / w
    , boundsTop = fromIntegral (frameY frame) / h
    , boundsRight = fromIntegral (frameX frame + frameWidth frame) / w
    , boundsBottom = fromIntegral (frameY frame + frameHeight frame) / h
    }
 where
  w = divisor (spriteWidth sprite)
  h = divisor (spriteHeight sprite)

{- | A pixel extent to divide by, never zero — a window or a sheet can report
no extent at all. A window counts in 'GL.GLsizei' and a sheet in 'Int', so this
takes either.
-}
divisor :: Integral a => a -> Float
divisor = fromIntegral . max 1

{- | How many elements one draw call issues: the indices when the primitive
has them, otherwise its vertices.
-}
elementCount :: Primitive -> GL.GLsizei
elementCount prim
  | Vector.null indices = fromIntegral (Vector.length (primitivePositions prim))
  | otherwise = fromIntegral (Vector.length indices)
 where
  indices = primitiveIndices prim
