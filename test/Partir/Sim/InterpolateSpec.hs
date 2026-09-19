module Partir.Sim.InterpolateSpec (
  test_interpolate,
  test_prune,
)
where

import Data.List (foldl')
import Data.Maybe (fromMaybe)
import Data.Word (Word64)
import Linear.Metric (dot, normalize, quadrance)
import Linear.Quaternion (Quaternion (..))
import Linear.V3 (V3 (..))
import Test.QuickCheck (Gen, Property, choose, forAll, suchThat)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, assertBool, testCase, (@?=))
import Test.Tasty.QuickCheck (testProperty)

import Partir.Sim.Interpolate (
  Delay (..),
  Horizon (..),
  RemoteHistory,
  RenderTime (..),
  Sample (..),
  emptyHistory,
  interpolate,
  prune,
  record,
 )
import Partir.World.Types (Pose (..), Quat, Tick (..), Vec3)

test_interpolate :: TestTree
test_interpolate =
  testGroup
    "interpolate"
    [ testCase "returns nothing for an empty history" $
        interpolate noDelay noExtrapolation (RenderTime 5) emptyHistory @?= Nothing
    , testCase "yields each sample's pose exactly at its tick" $ do
        posAt noDelay noExtrapolation 0 line `closeTo` origin
        posAt noDelay noExtrapolation 10 line `closeTo` far
    , testCase "tracks the linear midpoint between two samples" $
        posAt noDelay noExtrapolation 5 line `closeTo` V3 5 10 15
    , testCase "shifts the sampled instant back by the delay" $
        posAt (Delay (Tick 5)) noExtrapolation 10 line `closeTo` V3 5 10 15
    , testCase "holds the oldest pose before the buffer begins" $
        posAt noDelay noExtrapolation (-3) line `closeTo` origin
    , testCase "holds the newest pose past the buffer's end with no horizon" $
        posAt noDelay noExtrapolation 1000 line `closeTo` far
    , -- The line runs V3 1 2 3 per tick; three ticks past the newest sample.
      testCase "advances along the last observed velocity within the horizon" $
        posAt noDelay shortHorizon 13 line `closeTo` V3 13 26 39
    , testCase "settles at the horizon rather than drifting on" $
        posAt noDelay shortHorizon 1000 line `closeTo` V3 15 30 45
    , -- A quarter turn over the span, projected for a second span.
      testCase "carries the turn on past the newest sample" $
        orientation oneSpan 2 (poses origin noRotation origin (turnZ (pi / 4)))
          `sameRotationAs` turnZ (pi / 2)
    , testCase "holds a lone sample, having no velocity to project" $
        posAt noDelay shortHorizon 100 (record (Sample (Tick 0) (Pose far noRotation)) emptyHistory)
          `closeTo` far
    , testProperty "position moves monotonically toward the next sample" $
        forAll genVec3 $ \p0 ->
          forAll genVec3 $ \p1 ->
            forAll orderedFractions $ \(lo, hi) ->
              let hist = poses p0 noRotation p1 noRotation
                  a = sample lo hist
                  b = sample hi hist
               in movesToward (p1 ^-^ p0) (b ^-^ a)
    , testProperty "orientation rotates monotonically away from the start" $
        turnsOneWay noExtrapolation 0
    , testProperty "orientation keeps turning the same way past the newest sample" $
        turnsOneWay oneSpan 1
    ]

test_prune :: TestTree
test_prune =
  testGroup
    "prune"
    [ testCase "leaves an empty history empty" $
        prune noDelay (RenderTime 5) emptyHistory @?= emptyHistory
    , testCase "drops the samples below the pair bracketing the playback instant" $
        prune noDelay (RenderTime 5) ramp @?= samplesAt [4 .. 10]
    , testCase "shifts the playback instant back by the delay" $
        prune (Delay (Tick 3)) (RenderTime 8) ramp @?= samplesAt [4 .. 10]
    , testCase "keeps the sample the playback instant falls after" $
        prune noDelay (RenderTime 5.5) ramp @?= samplesAt [4 .. 10]
    , testCase "holds a history that reaches no further back than the playback instant" $
        prune (Delay (Tick 4)) (RenderTime 2) ramp @?= ramp
    , testCase "stays bounded under sustained recording" $
        let advance h n = prune (Delay (Tick 2)) (RenderTime (fromIntegral n)) (record (marker n) h)
         in foldl' advance emptyHistory [0 .. 999] @?= samplesAt [996 .. 999]
    , testProperty "leaves interpolate unchanged at or past the playback instant" $
        prunePreserves noExtrapolation
    , testProperty "keeps the pair extrapolation reckons from" $
        prunePreserves shortHorizon
    ]

-- Properties

-- Pruning is invisible to a render time at or past where it cut. The range
-- overhangs the ramp at both ends, so the poses clamped outside the buffer
-- are covered too.
prunePreserves :: Horizon -> Property
prunePreserves horizon =
  forAll (orderedPair (-2, 14)) $ \(cut, t) ->
    let pruned = prune noDelay (RenderTime cut) ramp
     in renderedAt noDelay horizon t pruned == renderedAt noDelay horizon t ramp

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

-- A sample whose position names its tick, so equality says which samples
-- survived a prune.
marker :: Word64 -> Sample
marker n = Sample (Tick n) (Pose (V3 (fromIntegral n) 0 0) noRotation)

samplesAt :: [Word64] -> RemoteHistory
samplesAt = foldl' (flip record) emptyHistory . fmap marker

-- The buffer the prune examples cut into.
ramp :: RemoteHistory
ramp = samplesAt [0 .. 10]

-- Helpers

renderedAt :: Delay -> Horizon -> Double -> RemoteHistory -> Maybe Pose
renderedAt delay horizon t = interpolate delay horizon (RenderTime t)

poseAt :: Delay -> Horizon -> Double -> RemoteHistory -> Pose
poseAt delay horizon t = fromMaybe (error "poseAt: empty history") . renderedAt delay horizon t

posAt :: Delay -> Horizon -> Double -> RemoteHistory -> Vec3
posAt delay horizon t = posePosition . poseAt delay horizon t

sample :: Double -> RemoteHistory -> Vec3
sample frac = posAt noDelay noExtrapolation (frac * spanTicks)

orientation :: Horizon -> Double -> RemoteHistory -> Quat
orientation horizon frac = poseOrientation . poseAt noDelay horizon (frac * spanTicks)

orderedFractions :: Gen (Double, Double)
orderedFractions = orderedPair (0, 1)

-- Two values from the range, smaller first.
orderedPair :: (Double, Double) -> Gen (Double, Double)
orderedPair range = do
  a <- choose range
  b <- choose range
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

-- Slack for an example, where one blend must match stated arithmetic.
tolerance :: Double
tolerance = 1e-9

-- The largest difference between two vectors or quaternions on any one
-- component.
gap :: (Applicative f, Foldable f) => f Double -> f Double -> Double
gap a b = maximum (abs <$> ((-) <$> a <*> b))

closeTo :: Vec3 -> Vec3 -> Assertion
closeTo = within "close to"

sameRotationAs :: Quat -> Quat -> Assertion
sameRotationAs = within "the same rotation as"

within :: (Applicative f, Foldable f, Show (f Double)) => String -> f Double -> f Double -> Assertion
within relation a b =
  assertBool
    (show a <> " is not " <> relation <> " " <> show b <> " (gap " <> show (gap a b) <> ")")
    (gap a b < tolerance)

(^-^) :: Vec3 -> Vec3 -> Vec3
(^-^) = (-)
