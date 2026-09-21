-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Partir.Client.GLUT.ViewSpec (
  test_camera,
  test_elementCount,
  test_frameBounds,
  test_overlayBounds,
)
where

import qualified Data.Vector as Vector
import qualified Data.Vector.Storable as Storable
import qualified Graphics.Rendering.OpenGL as GL
import Linear.Matrix ((!*))
import Linear.V3 (V3 (..))
import Linear.V4 (V4 (..))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

import Partir.Asset (Frame (..), Primitive (..), Sprite (..))
import Partir.Client.GLUT.View (
  Bounds (..),
  camera,
  elementCount,
  frameBounds,
  overlayBounds,
 )

{- | An asset modelled about the origin lands in the middle of the window,
whatever shape the window is.
-}
test_camera :: TestTree
test_camera =
  testGroup
    "camera"
    [ testCase "puts the world origin in front of the viewpoint" $
        assertBool "the origin is behind the near plane" (depth (project landscape origin) > 0)
    , testCase "centres the world origin in a landscape window" $
        assertCentred (project landscape origin)
    , testCase "centres the world origin in a portrait window" $
        assertCentred (project portrait origin)
    , -- The viewpoint looks at the origin, so stepping the same distance
      -- again past it puts a point behind the near plane rather than in view.
      testCase "drops what sits behind the viewpoint" $
        assertBool
          "a point behind the viewpoint still projects in front"
          (depth (project landscape (V4 4.4 3.2 5.2 1)) < 0)
    ]

-- | Counting the wrong one draws part of a mesh, or runs off the end of it.
test_elementCount :: TestTree
test_elementCount =
  testGroup
    "elementCount"
    [ testCase "counts the indices of an indexed primitive" $
        elementCount (triangleWith (Vector.fromList [0, 1, 2, 0, 2, 1])) @?= 6
    , testCase "counts the vertices when the primitive has no indices" $
        elementCount (triangleWith Vector.empty) @?= 3
    ]

{- | A clip-space unit spans half the window along each axis, and those halves
differ, so a rectangle fixed in clip space comes out stretched.
-}
test_overlayBounds :: TestTree
test_overlayBounds =
  testGroup
    "overlayBounds"
    [ testCase "holds a square footprint in a landscape window" $
        assertSquare landscape
    , testCase "holds a square footprint in a portrait window" $
        assertSquare portrait
    , testCase "insets the icon from the window's top-left corner" $ do
        let icon = overlayBounds landscape
        assertBool "the icon is not left of centre" (boundsLeft icon < 0)
        assertBool "the icon is not above centre" (boundsTop icon > 0)
    , -- Clip space runs upward and a window's rows run downward, so the icon's
      -- bottom edge is the lesser of the two.
      testCase "orders the bounds from the top-left corner" $ do
        let icon = overlayBounds landscape
        assertBool
          "the left edge is not left of the right"
          (boundsLeft icon < boundsRight icon)
        assertBool
          "the top edge is not above the bottom"
          (boundsTop icon > boundsBottom icon)
    , -- A window with no height would divide by it.
      testCase "survives a window collapsed to nothing" $
        assertSquare (GL.Size 0 0)
    ]

{- | Texture coordinates run 0 to 1 over the sheet however many pixels it is,
so a frame's bounds are its pixels over the sheet's.
-}
test_frameBounds :: TestTree
test_frameBounds =
  testGroup
    "frameBounds"
    [ testCase "spans the whole sheet for a frame that covers it" $
        frameBounds (sheet 64 64) (Frame 0 0 64 64) @?= Bounds 0 0 1 1
    , testCase "takes the quarter a frame occupies" $
        frameBounds (sheet 64 64) (Frame 16 16 16 16) @?= Bounds 0.25 0.25 0.5 0.5
    , -- A frame's own y counts down from the top, and so does the coordinate
      -- it becomes. Flipping either one here would swap these two.
      testCase "leaves the vertical coordinate running downward" $ do
        let bottomLeft = frameBounds (sheet 64 64) (Frame 0 48 16 16)
        (boundsTop bottomLeft, boundsBottom bottomLeft) @?= (0.75, 1)
    , testCase "survives a sheet of no extent" $
        frameBounds (sheet 0 0) (Frame 0 0 0 0) @?= Bounds 0 0 0 0
    ]

-- | A sheet of the given size, holding no pixels and no frames.
sheet :: Int -> Int -> Sprite
sheet width height =
  Sprite
    { spriteWidth = width
    , spriteHeight = height
    , spritePixels = Storable.empty
    , spriteFrames = Vector.empty
    }

{- | The icon covers as many pixels across as it does down. Clip space spans
two units over each axis, so an extent there is that fraction of the window.
-}
assertSquare :: GL.Size -> IO ()
assertSquare size@(GL.Size width height) =
  assertBool
    ("expected a square icon, got " ++ show (across, down) ++ " pixels")
    (abs (across - down) < tolerance)
 where
  icon = overlayBounds size
  across = (boundsRight icon - boundsLeft icon) / 2 * fromIntegral (max 1 width)
  down = (boundsTop icon - boundsBottom icon) / 2 * fromIntegral (max 1 height)
  tolerance = 1e-3

-- | Three vertices, and whichever indices the example wants over them.
triangleWith :: Vector.Vector Word -> Primitive
triangleWith indices =
  Primitive
    { primitivePositions = Vector.fromList [V3 0 0 0, V3 1 0 0, V3 0 1 0]
    , primitiveIndices = Vector.map fromIntegral indices
    , primitiveNormals = Vector.empty
    , primitiveMaterial = Nothing
    }

origin :: V4 Float
origin = V4 0 0 0 1

landscape, portrait :: GL.Size
landscape = GL.Size 800 600
portrait = GL.Size 600 800

project :: GL.Size -> V4 Float -> V4 Float
project size point = camera size !* point

depth :: V4 Float -> Float
depth (V4 _ _ _ w) = w

-- | The centre of the window is the origin of normalised device space.
assertCentred :: V4 Float -> IO ()
assertCentred clip@(V4 x y _ w) =
  assertBool
    ("expected the centre of the window, got " ++ show clip)
    (abs (x / w) < tolerance && abs (y / w) < tolerance)
 where
  tolerance = 1e-5
