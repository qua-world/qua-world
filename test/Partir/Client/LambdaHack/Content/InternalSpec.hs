module Partir.Client.LambdaHack.Content.InternalSpec
  ( main
  , spec
  )
where

import           Test.Hspec                     ( Spec
                                                , describe
                                                , hspec
                                                , it
                                                , parallel
                                                , shouldBe
                                                )

import           Partir.Client.LambdaHack.Content.Internal

main :: IO ()
main = hspec spec

spec :: Spec
spec = parallel $ do
  describe "caves" $ it "validates" $ validateCaves `shouldBe` []
  describe "items" $ it "validates" $ validateItems `shouldBe` []
  describe "modes" $ it "validates" $ validateModes `shouldBe` []
  describe "places" $ it "validates" $ validatePlaces `shouldBe` []
  describe "tiles" $ it "validates" $ validateTiles `shouldBe` []
