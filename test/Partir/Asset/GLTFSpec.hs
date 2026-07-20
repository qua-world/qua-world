module Partir.Asset.GLTFSpec
  ( spec
  )
where

import Test.Hspec

import Partir.Asset
  ( Mesh (..)
  , Primitive (..)
  , indexCount
  , vertexCount
  )
import Partir.Asset.GLTF (loadAsset)

-- | The committed placeholder cube: 6 faces * 4 corners, 6 faces * 2 triangles,
-- one material. Kept in step with @examples/avatar.glb@ (see @examples/README.md@).
spec :: Spec
spec =
  describe "loadAsset" $ do
    it "loads the example cube's geometry counts" $ do
      mesh <- loadAsset "examples/avatar.glb"
      vertexCount mesh `shouldBe` 24
      indexCount mesh `shouldBe` 36

    it "flattens to a single primitive carrying its normals" $ do
      mesh <- loadAsset "examples/avatar.glb"
      case meshPrimitives mesh of
        [prim] -> length (primitiveNormals prim) `shouldBe` 24
        prims -> expectationFailure ("expected one primitive, got " ++ show (length prims))

    it "preserves the primitive's material binding" $ do
      mesh <- loadAsset "examples/avatar.glb"
      case meshPrimitives mesh of
        [prim] -> primitiveMaterial prim `shouldBe` Just 0
        prims -> expectationFailure ("expected one primitive, got " ++ show (length prims))
