module Partir.Sim.InterpolateSpec
  ( spec
  )
where

import Linear.Metric (dot, normalize, quadrance)
import Linear.Quaternion (Quaternion (..))
import Linear.V3 (V3 (..))
import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck (Gen, choose, forAll, suchThat)

import Partir.Sim.Interpolate
  ( RemoteHistory
  , RenderTime (..)
  , Pose (..)
  , Snapshot (..)
  , emptyHistory
  , interpolate
  , record
  )
import Partir.World.Types (Quat, Tick (..), Vec3)

spec :: Spec
spec = do
  describe "interpolate" $ do
    it "returns nothing for an empty history" $
      interpolate (Tick 0) (RenderTime 5) emptyHistory `shouldBe` Nothing

    it "yields each snapshot's pose exactly at its tick" $ do
      posAt 0 line `closeTo` origin
      posAt 10 line `closeTo` far

    it "tracks the linear midpoint between two snapshots" $
      posAt 5 line `closeTo` V3 5 10 15

    it "shifts the sampled instant back by the delay" $
      -- delay 5, now 10 -> target 5 -> the midpoint.
      fmap posePosition (interpolate (Tick 5) (RenderTime 10) line)
        `shouldSatisfy` closeToJust (V3 5 10 15)

    it "holds the oldest pose before the buffer begins" $
      posAt (-3) line `closeTo` origin

    it "holds the newest pose past the buffer's end" $
      posAt 1000 line `closeTo` far

    prop "position moves monotonically toward the next snapshot" $
      forAll genVec3 $ \p0 ->
        forAll genVec3 $ \p1 ->
          forAll orderedFractions $ \(lo, hi) ->
            let hist = poses p0 noRotation p1 noRotation
                a = sample lo hist
                b = sample hi hist
            in movesToward (p1 ^-^ p0) (b ^-^ a)

    prop "orientation rotates monotonically away from the start" $
      forAll genUnitQuat $ \q0 ->
        forAll (genUnitQuat `suchThat` notAntipodalTo q0) $ \q1 ->
          forAll orderedFractions $ \(lo, hi) ->
            let hist = poses origin q0 origin q1
                near = dot q0 (orientation lo hist)
                farr = dot q0 (orientation hi hist)
            in near >= farr - epsilon

-- Fixtures

origin :: Vec3
origin = V3 0 0 0

far :: Vec3
far = V3 10 20 30

noRotation :: Quat
noRotation = Quaternion 1 (V3 0 0 0)

-- A two-snapshot history spanning ticks 0..10, both facing forward.
line :: RemoteHistory
line =
  record (Snapshot (Tick 10) (Pose far noRotation)) $
    record (Snapshot (Tick 0) (Pose origin noRotation)) emptyHistory

-- A two-snapshot history at ticks 0 and 1000, so a fraction in [0, 1] maps
-- onto a render time in [0, 1000].
poses :: Vec3 -> Quat -> Vec3 -> Quat -> RemoteHistory
poses p0 q0 p1 q1 =
  record (Snapshot (Tick 1000) (Pose p1 q1)) $
    record (Snapshot (Tick 0) (Pose p0 q0)) emptyHistory

-- Helpers

-- Interpolated position at a render time, with no delay.
posAt :: Double -> RemoteHistory -> Vec3
posAt t = maybe (error "posAt: empty") posePosition . interpolate (Tick 0) (RenderTime t)

sample :: Double -> RemoteHistory -> Vec3
sample frac = posAt (frac * 1000)

orientation :: Double -> RemoteHistory -> Quat
orientation frac =
  maybe (error "orientation: empty") poseOrientation
    . interpolate (Tick 0) (RenderTime (frac * 1000))

orderedFractions :: Gen (Double, Double)
orderedFractions = do
  a <- choose (0, 1)
  b <- choose (0, 1)
  pure (min a b, max a b)

genVec3 :: Gen Vec3
genVec3 = V3 <$> coord <*> coord <*> coord
  where
    coord = choose (-100, 100)

genUnitQuat :: Gen Quat
genUnitQuat =
  normalize
    <$> (Quaternion <$> coord <*> genVec3) `suchThat` ((> 1e-3) . quadrance)
  where
    coord = choose (-100, 100)

-- A step @d@ moves toward direction @dir@ when it does not oppose it on any
-- axis: linear interpolation can only carry each component toward the target.
movesToward :: Vec3 -> Vec3 -> Bool
movesToward dir d = and ((\x y -> x * y >= negate epsilon) <$> dir <*> d)

notAntipodalTo :: Quat -> Quat -> Bool
notAntipodalTo q0 q1 = dot q0 q1 >= 0

epsilon :: Double
epsilon = 1e-6

closeTo :: Vec3 -> Vec3 -> Expectation
closeTo a b = maximum (abs <$> (a ^-^ b)) `shouldSatisfy` (< 1e-9)

closeToJust :: Vec3 -> Maybe Vec3 -> Bool
closeToJust want = maybe False (\got -> maximum (abs <$> (want ^-^ got)) < 1e-9)

(^-^) :: Vec3 -> Vec3 -> Vec3
(^-^) = (-)
