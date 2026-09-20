-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Partir.Client.GLUT.ViewSpec (
  test_camera,
  test_elementCount,
)
where

import qualified Data.Vector as Vector
import qualified Graphics.Rendering.OpenGL as GL
import Linear.Matrix ((!*))
import Linear.V3 (V3 (..))
import Linear.V4 (V4 (..))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

import Partir.Asset (Primitive (..))
import Partir.Client.GLUT.View (camera, elementCount)

{- | "In front of the camera" is the acceptance criterion the screenshot
checks by eye. These hold it without a context: an asset modelled about the
origin lands in the middle of the window, whatever shape the window is.
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

{- | A draw call reads indices when the primitive carries them, and the
vertices themselves when it does not. Counting the wrong one draws part of a
mesh or runs off the end of it.
-}
test_elementCount :: TestTree
test_elementCount =
  testGroup
    "elementCount"
    [ testCase "counts the indices of an indexed primitive" $
        elementCount (triangleWith (Vector.fromList [0, 1, 2, 0, 2, 1])) @?= 6
    , testCase "counts the vertices when the primitive has no indices" $
        elementCount (triangleWith Vector.empty) @?= 3
    ]

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

{- | A projected point sits at the centre of the window when dividing by the
homogeneous coordinate leaves it at the origin of normalised device space.
-}
assertCentred :: V4 Float -> IO ()
assertCentred clip@(V4 x y _ w) =
  assertBool
    ("expected the centre of the window, got " ++ show clip)
    (abs (x / w) < tolerance && abs (y / w) < tolerance)
 where
  tolerance = 1e-5
