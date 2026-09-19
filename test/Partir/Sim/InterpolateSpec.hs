module Partir.Sim.InterpolateSpec (
  spec,
)
where

import Data.Maybe (fromMaybe)
import Linear.Metric (dot, normalize, quadrance)
import Linear.Quaternion (Quaternion (..))
import Linear.V3 (V3 (..))
import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck (Gen, Property, choose, forAll, suchThat)

import Partir.Sim.Interpolate (
  Delay (..),
  Horizon (..),
  RemoteHistory,
  RenderTime (..),
  Sample (..),
  emptyHistory,
  interpolate,
  record,
 )
import Partir.World.Types (Pose (..), Quat, Tick (..), Vec3)

spec :: Spec
spec = do
  describe "interpolate" $ do
    it "returns nothing for an empty history" $
      interpolate noDelay noExtrapolation (RenderTime 5) emptyHistory `shouldBe` Nothing

    it "yields each sample's pose exactly at its tick" $ do
      posAt noExtrapolation 0 line `closeTo` origin
      posAt noExtrapolation 10 line `closeTo` far

    it "tracks the linear midpoint between two samples" $
      posAt noExtrapolation 5 line `closeTo` V3 5 10 15

    it "shifts the sampled instant back by the delay" $
      -- delay 5, now 10 -> target 5 -> the midpoint.
      fmap posePosition (interpolate (Delay (Tick 5)) noExtrapolation (RenderTime 10) line)
        `shouldSatisfy` closeToJust (V3 5 10 15)

    it "holds the oldest pose before the buffer begins" $
      posAt noExtrapolation (-3) line `closeTo` origin

    it "holds the newest pose past the buffer's end with no horizon" $
      posAt noExtrapolation 1000 line `closeTo` far

    it "advances along the last observed velocity within the horizon" $
      -- line runs V3 1 2 3 per tick; three ticks past the newest sample.
      posAt shortHorizon 13 line `closeTo` V3 13 26 39

    it "settles at the horizon rather than drifting on" $
      posAt shortHorizon 1000 line `closeTo` V3 15 30 45

    it "carries the turn on past the newest sample" $
      -- A quarter turn over the span, projected for a second span.
      orientation oneSpan 2 (poses origin noRotation origin (turnZ (pi / 4)))
        `sameRotationAs` turnZ (pi / 2)

    it "holds a lone sample, having no velocity to project" $
      posAt shortHorizon 100 (record (Sample (Tick 0) (Pose far noRotation)) emptyHistory)
        `closeTo` far

    prop "position moves monotonically toward the next sample" $
      forAll genVec3 $ \p0 ->
        forAll genVec3 $ \p1 ->
          forAll orderedFractions $ \(lo, hi) ->
            let hist = poses p0 noRotation p1 noRotation
                a = sample lo hist
                b = sample hi hist
             in movesToward (p1 ^-^ p0) (b ^-^ a)

    prop "orientation rotates monotonically away from the start" $
      turnsOneWay noExtrapolation 0

    prop "orientation keeps turning the same way past the newest sample" $
      turnsOneWay oneSpan 1

-- Properties

-- A turn that never reverses: across a one-span window, a later instant sits
-- no closer to the starting orientation than an earlier one. The window opens
-- @from@ spans in, so 0 covers the gap between the samples and 1 the
-- extrapolated stretch past the newest.
turnsOneWay :: Horizon -> Double -> Property
turnsOneWay horizon from =
  forAll genUnitQuat $ \q0 ->
    forAll (genUnitQuat `suchThat` notAntipodalTo q0) $ \q1 ->
      forAll orderedFractions $ \(lo, hi) ->
        let hist = poses origin q0 origin q1
            earlier = dot q0 (orientation horizon (from + lo) hist)
            later = dot q0 (orientation horizon (from + hi) hist)
         in earlier >= later - epsilon

-- Fixtures

origin :: Vec3
origin = V3 0 0 0

far :: Vec3
far = V3 10 20 30

noRotation :: Quat
noRotation = Quaternion 1 (V3 0 0 0)

-- Playback with no lag, so a render time reads as the tick of that number.
noDelay :: Delay
noDelay = Delay (Tick 0)

-- The horizon that holds the newest pose rather than projecting from it.
noExtrapolation :: Horizon
noExtrapolation = Horizon (Tick 0)

-- Narrower than the `line` fixture's span, so a render time can land inside
-- the horizon or past it.
shortHorizon :: Horizon
shortHorizon = Horizon (Tick 5)

-- The ticks a `poses` history covers, so a fraction of it scales to a render
-- time.
spanTicks :: Double
spanTicks = 1000

-- A horizon as wide as a `poses` history, so a fraction in [1, 2] maps onto
-- the whole extrapolated window.
oneSpan :: Horizon
oneSpan = Horizon (Tick (round spanTicks))

turnZ :: Double -> Quat
turnZ theta = Quaternion (cos (theta / 2)) (V3 0 0 (sin (theta / 2)))

-- A two-sample history spanning ticks 0..10, both facing forward.
line :: RemoteHistory
line =
  record (Sample (Tick 10) (Pose far noRotation)) $
    record (Sample (Tick 0) (Pose origin noRotation)) emptyHistory

-- A two-sample history spanning `spanTicks`, so a fraction in [0, 1] maps
-- onto a render time inside it.
poses :: Vec3 -> Quat -> Vec3 -> Quat -> RemoteHistory
poses p0 q0 p1 q1 =
  record (Sample (Tick (round spanTicks)) (Pose p1 q1)) $
    record (Sample (Tick 0) (Pose p0 q0)) emptyHistory

-- Helpers

-- Pose at a render time.
poseAt :: Horizon -> Double -> RemoteHistory -> Pose
poseAt horizon t =
  fromMaybe (error "poseAt: empty history") . interpolate noDelay horizon (RenderTime t)

posAt :: Horizon -> Double -> RemoteHistory -> Vec3
posAt horizon t = posePosition . poseAt horizon t

sample :: Double -> RemoteHistory -> Vec3
sample frac = posAt noExtrapolation (frac * spanTicks)

orientation :: Horizon -> Double -> RemoteHistory -> Quat
orientation horizon frac = poseOrientation . poseAt horizon (frac * spanTicks)

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

-- Slack for a property, which compares two blends and so carries the error
-- of both.
epsilon :: Double
epsilon = 1e-6

-- Slack for an expectation, where one blend must match stated arithmetic.
tolerance :: Double
tolerance = 1e-9

-- The largest difference between two vectors or quaternions on any one
-- component.
gap :: (Applicative f, Foldable f) => f Double -> f Double -> Double
gap a b = maximum (abs <$> ((-) <$> a <*> b))

closeTo :: Vec3 -> Vec3 -> Expectation
closeTo a b = gap a b `shouldSatisfy` (< tolerance)

sameRotationAs :: Quat -> Quat -> Expectation
sameRotationAs a b = gap a b `shouldSatisfy` (< tolerance)

closeToJust :: Vec3 -> Maybe Vec3 -> Bool
closeToJust want = maybe False ((< tolerance) . gap want)

(^-^) :: Vec3 -> Vec3 -> Vec3
(^-^) = (-)
