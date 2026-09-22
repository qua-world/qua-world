-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Asset.OBJ
Description : Load Wavefront OBJ files into a renderer-ready 'Asset.Mesh'

Reads the polygon faces of an OBJ file into a single 'Asset.Primitive'. The
@wavefront@ dependency is confined to this module: none of it appears in the
returned type.

A face corner indexes its position and its normal separately, while a
primitive shares one index across both, so each distinct pairing becomes one
vertex. Polygons are split into triangle fans, which is exact for the convex
faces exporters write.

Texture coordinates and @.mtl@ materials are not read, and relative
(negative) indices do not parse.
-}
module Partir.Asset.OBJ (
  ObjLoadError (..),
  loadAsset,
)
where

import Control.Exception (Exception)
import Data.List (mapAccumL, sortOn)
import qualified Data.Map.Strict as Map
import Data.Vector (Vector)
import qualified Data.Vector as Vector
import Data.Word (Word32)
import Linear.V3 (V3 (..))

import qualified Codec.Wavefront as OBJ

import qualified Partir.Asset as Asset

{- | An OBJ file that could not be read as a mesh. The 'Exception' instance lets
a caller 'throwIO' it where a decode failure should be fatal, as the client
does at startup.
-}
data ObjLoadError
  = -- | The text did not tokenize, with @wavefront@'s diagnostic.
    ObjSyntaxError String
  | {- | A face referred to a position or normal the file does not declare, by
    its one-based index.
    -}
    ObjDanglingIndex Int
  deriving (Eq, Show)

instance Exception ObjLoadError

{- | Load an OBJ file into a renderer-ready mesh. A malformed file is
anticipated, so it comes back as a 'Left'; a missing or unreadable file is an
I\/O failure and surfaces as the 'IOError' thrown by reading it.
-}
loadAsset :: FilePath -> IO (Either ObjLoadError Asset.Mesh)
loadAsset path = either (Left . ObjSyntaxError) fromObj <$> OBJ.fromFile path

fromObj :: OBJ.WavefrontOBJ -> Either ObjLoadError Asset.Mesh
fromObj obj
  | null corners = Right (Asset.Mesh [])
  | otherwise = do
      positions <- traverse (fmap location . select (OBJ.objLocations obj) . cornerLocation) corners
      normals <- traverse (traverse (fmap normal . select (OBJ.objNormals obj))) (traverse cornerNormal corners)
      pure $
        Asset.Mesh
          [ Asset.Primitive
              { Asset.primitivePositions = Vector.fromList positions
              , Asset.primitiveIndices = indices
              , Asset.primitiveNormals = maybe Vector.empty Vector.fromList normals
              , Asset.primitiveMaterial = Nothing
              }
          ]
 where
  (corners, indices) = weld (concatMap (triangles . OBJ.elValue) (Vector.toList (OBJ.objFaces obj)))
  location l = V3 (OBJ.locX l) (OBJ.locY l) (OBJ.locZ l)
  normal n = V3 (OBJ.norX n) (OBJ.norY n) (OBJ.norZ n)

-- | A face's corners as a triangle fan around its first corner.
triangles :: OBJ.Face -> [OBJ.FaceIndex]
triangles (OBJ.Face a b c rest) =
  concat (zipWith (\x y -> [a, x, y]) (b : c : rest) (c : rest))

{- | The attributes one face corner selects, by one-based index. Texture
coordinates are left out, so corners differing only there share a vertex.
-}
data Corner = Corner
  { cornerLocation :: Int
  , cornerNormal :: Maybe Int
  }
  deriving (Eq, Ord)

{- | Number each distinct corner in order of first use, returning the corners
and the index of every face corner.
-}
weld :: [OBJ.FaceIndex] -> ([Corner], Vector Word32)
weld faceCorners = (map fst (sortOn snd (Map.toList seen)), Vector.fromList indices)
 where
  (seen, indices) = mapAccumL number Map.empty (map corner faceCorners)
  number known c =
    case Map.lookup c known of
      Just i -> (known, i)
      Nothing -> let i = fromIntegral (Map.size known) in (Map.insert c i known, i)
  corner c = Corner{cornerLocation = OBJ.faceLocIndex c, cornerNormal = OBJ.faceNorIndex c}

-- | Look up a one-based OBJ index.
select :: Vector a -> Int -> Either ObjLoadError a
select xs i = maybe (Left (ObjDanglingIndex i)) Right (xs Vector.!? (i - 1))
