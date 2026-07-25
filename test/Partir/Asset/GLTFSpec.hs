module Partir.Asset.GLTFSpec
  ( spec
  )
where

import qualified Data.ByteString.Char8 as ByteString
import Test.Hspec

import Partir.Asset
  ( Mesh (..)
  , Primitive (..)
  , indexCount
  , vertexCount
  )
import Partir.Asset.GLTF (GltfLoadError, loadAsset, loadAssetBytes)

-- | @examples/avatar.glb@ is a placeholder unit cube standing in for real
-- Blockbench content: 6 faces * 4 corners = 24 vertices, 6 faces * 2 triangles
-- = 36 indices, one material. These expectations track that file.
spec :: Spec
spec = do
  describe "loadAsset" $ do
    it "loads the example cube's geometry counts" $ do
      mesh <- loadCube
      vertexCount mesh `shouldBe` 24
      indexCount mesh `shouldBe` 36

    it "flattens to a single primitive carrying its normals" $ do
      mesh <- loadCube
      case meshPrimitives mesh of
        [prim] -> length (primitiveNormals prim) `shouldBe` 24
        prims -> expectationFailure ("expected one primitive, got " ++ show (length prims))

    it "preserves the primitive's material binding" $ do
      mesh <- loadCube
      case meshPrimitives mesh of
        [prim] -> primitiveMaterial prim `shouldBe` Just 0
        prims -> expectationFailure ("expected one primitive, got " ++ show (length prims))

  describe "loadAssetBytes" $
    it "returns the decode failure for non-GLB bytes" $ do
      result <- loadAssetBytes (ByteString.pack "not a glb")
      case result :: Either GltfLoadError Mesh of
        Left _ -> pure ()
        Right _ -> expectationFailure "expected a decode failure"

-- | Load the example cube, failing the example with the decode error on 'Left'.
loadCube :: IO Mesh
loadCube = loadAsset "examples/avatar.glb" >>= either (fail . show) pure
