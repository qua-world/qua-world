-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Asset
Description : Renderer-ready mesh geometry, independent of any source format

A 'Mesh' is the geometry a client draws: 'Primitive's, each a triangle list of
positions with optional indices, normals, and a material binding. The type
names no source format, so the renderer depends on this vocabulary and each
loader converts into it.

Coordinates are 'Float' rather than the 'Partir.World.Types.Vec3' the
simulation uses: this side of the boundary feeds vertex buffers, and OpenGL
reads single precision.
-}
module Partir.Asset (
  Mesh (..),
  Primitive (..),
  vertexCount,
  indexCount,
)
where

import Data.Vector (Vector)
import qualified Data.Vector as Vector
import Data.Word (Word32)
import Linear.V3 (V3)

-- | A drawable asset: the flattened primitives of every mesh in a source file.
newtype Mesh = Mesh
  { meshPrimitives :: [Primitive]
  -- ^ Draw calls, in source order.
  }
  deriving (Eq, Show)

-- | One triangle-list draw call.
data Primitive = Primitive
  { primitivePositions :: Vector (V3 Float)
  -- ^ Vertex positions in model space.
  , primitiveIndices :: Vector Word32
  {- ^ Triangle indices into 'primitivePositions'. Empty draws the positions in
  order.
  -}
  , primitiveNormals :: Vector (V3 Float)
  -- ^ Per-vertex normals, or empty when the source omits them.
  , primitiveMaterial :: Maybe Int
  -- ^ Index of the bound material in the source document, if any.
  }
  deriving (Eq, Show)

-- | Total vertices across every primitive.
vertexCount :: Mesh -> Int
vertexCount = sum . map (Vector.length . primitivePositions) . meshPrimitives

-- | Total triangle indices across every primitive.
indexCount :: Mesh -> Int
indexCount = sum . map (Vector.length . primitiveIndices) . meshPrimitives
