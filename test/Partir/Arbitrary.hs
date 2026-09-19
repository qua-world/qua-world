-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT
{-# OPTIONS_GHC -fno-warn-orphans #-}

{- |
Module      : Partir.Arbitrary
Description : Shared generators and shrinkers for the world types

Every spec draws its world values from here, so a value shrinks the same way
wherever it surfaces and a generator fixed once is fixed everywhere. The
instances are orphans by necessity: the types belong to the library and the
generators to the test suite, and the alternative is QuickCheck in the
library's own dependencies.

Every instance defines 'shrink'. The default, @const []@, reports the first
failing case whole, and a failing case here is a pose of six unrounded
'Double's or an event sequence hundreds long — unreadable as a bug report.
-}
module Partir.Arbitrary (
  Position (..),
  UnitQuat (..),
  Window (..),
  orderedBelow,
  shrinkOrderedBelow,
)
where

import qualified Data.Map.Strict as Map
import Data.Text (pack, unpack)
import Linear.Metric (normalize, quadrance)
import Linear.Quaternion (Quaternion (..))
import Linear.V3 (V3 (..))
import Test.QuickCheck (
  Arbitrary (arbitrary, shrink),
  Gen,
  choose,
  oneof,
  suchThat,
 )

import Partir.World.Event (Event (..))
import Partir.World.Scene (Scene (..), apply, empty)
import Partir.World.Types (
  AgentId (..),
  EntityId (..),
  Pose (..),
  Quat,
  Tick (..),
  Vec3,
 )

{- | A world position whose coordinates stay small enough that blending two of
them keeps its significant digits. Unbounded 'Double's put @1e300@ beside
@1e-300@, where the sum drops the smaller term outright and a monotonicity
property fails on floating point rather than on the code it tests.
-}
newtype Position = Position {unPosition :: Vec3}
  deriving (Eq, Show)

instance Arbitrary Position where
  arbitrary = Position <$> coordinates

  -- Shrinking the tuple walks one coordinate at a time, and 'shrink' on a
  -- 'Double' only ever reduces magnitude, so a shrunk coordinate stays inside
  -- a bound centred on zero.
  shrink (Position (V3 x y z)) =
    [Position (V3 x' y' z') | (x', y', z') <- shrink (x, y, z)]

{- | A normalized, non-degenerate orientation. Shrinking renormalizes, so every
candidate still names a rotation; shrinking the components alone would walk
the quaternion to zero, which names none.
-}
newtype UnitQuat = UnitQuat {unUnitQuat :: Quat}
  deriving (Eq, Show)

instance Arbitrary UnitQuat where
  arbitrary = UnitQuat . normalize <$> nondegenerate
   where
    nondegenerate =
      (Quaternion <$> coordinate <*> coordinates)
        `suchThat` ((> degenerate) . quadrance)

  shrink (UnitQuat (Quaternion w (V3 x y z))) =
    [ UnitQuat (normalize q)
    | (w', x', y', z') <- shrink (w, x, y, z)
    , let q = Quaternion w' (V3 x' y' z')
    , quadrance q > degenerate
    ]

{- | Two fractions of a span, the earlier first — a window into @[0, 1]@, the
shape a property needs to ask whether a blend moved one way between two
instants.
-}
newtype Window = Window (Double, Double)
  deriving (Eq, Show)

instance Arbitrary Window where
  arbitrary = Window <$> orderedBelow unitRange
  shrink (Window w) = Window <$> shrinkOrderedBelow unitRange w

{- | A value from the range paired with one at or below it, the lower first.

Drawing the upper bound uniformly and the lower beneath it leaves the upper
uniform over the whole range. Taking the smaller and larger of two uniform
draws instead — the obvious way to write this — biases the upper toward the
top, which starves whichever partition sits at the bottom of the range: over
@(-2, 14)@ it reaches below zero in under two runs per hundred.
-}
orderedBelow :: (Double, Double) -> Gen (Double, Double)
orderedBelow (lo, hi) = do
  upper <- choose (lo, hi)
  lower <- choose (lo, upper)
  pure (lower, upper)

-- | Shrink a pair from 'orderedBelow', holding it ordered and inside the range.
shrinkOrderedBelow :: (Double, Double) -> (Double, Double) -> [(Double, Double)]
shrinkOrderedBelow (lo, hi) (lower, upper) =
  [(lower', upper) | lower' <- shrink lower, inRange lower', lower' <= upper]
    <> [(lower, upper') | upper' <- shrink upper, inRange upper', lower <= upper']
 where
  inRange x = lo <= x && x <= hi

instance Arbitrary AgentId where
  arbitrary = AgentId <$> arbitrary
  shrink (AgentId n) = AgentId <$> shrink n

instance Arbitrary EntityId where
  arbitrary = EntityId <$> arbitrary
  shrink (EntityId n) = EntityId <$> shrink n

instance Arbitrary Tick where
  arbitrary = Tick <$> arbitrary
  shrink (Tick n) = Tick <$> shrink n

instance Arbitrary Pose where
  arbitrary = do
    Position p <- arbitrary
    UnitQuat q <- arbitrary
    pure (Pose p q)

  shrink (Pose p q) =
    [Pose (unPosition p') (unUnitQuat q') | (p', q') <- shrink (Position p, UnitQuat q)]

instance Arbitrary Event where
  arbitrary =
    oneof
      [ Spawn <$> arbitrary <*> arbitrary <*> arbitrary <*> position <*> orientation
      , Despawn <$> arbitrary <*> arbitrary <*> arbitrary
      , Move <$> arbitrary <*> arbitrary <*> arbitrary <*> position
      , Look <$> arbitrary <*> arbitrary <*> arbitrary <*> orientation
      , Speak <$> arbitrary <*> arbitrary <*> (pack <$> arbitrary)
      , Interact <$> arbitrary <*> arbitrary <*> arbitrary
      ]
   where
    position = unPosition <$> arbitrary
    orientation = unUnitQuat <$> arbitrary

  -- Shrinking through the tuple instances walks one field at a time, which is
  -- what makes the reported counterexample the smallest failing event rather
  -- than the first.
  shrink (Spawn t a e p q) =
    [ Spawn t' a' e' (unPosition p') (unUnitQuat q')
    | (t', a', e', p', q') <- shrink (t, a, e, Position p, UnitQuat q)
    ]
  shrink (Despawn t a e) = [Despawn t' a' e' | (t', a', e') <- shrink (t, a, e)]
  shrink (Move t a e p) =
    [Move t' a' e' (unPosition p') | (t', a', e', p') <- shrink (t, a, e, Position p)]
  shrink (Look t a e q) =
    [Look t' a' e' (unUnitQuat q') | (t', a', e', q') <- shrink (t, a, e, UnitQuat q)]
  shrink (Speak t a m) = [Speak t' a' (pack m') | (t', a', m') <- shrink (t, a, unpack m)]
  shrink (Interact t a e) = [Interact t' a' e' | (t', a', e') <- shrink (t, a, e)]

{- | A scene reached by applying events, which is the only way one arises in
the running client.

Shrinking drops entities and lowers the tick directly rather than shrinking
the events behind them. Every such scene is still reachable — spawn what
remains, then any event at the tick — so a counterexample stays a state the
client can actually be in.
-}
instance Arbitrary Scene where
  arbitrary = foldr apply empty <$> (arbitrary :: Gen [Event])

  shrink (Scene t es) =
    [Scene t' es | t' <- shrink t]
      <> [Scene t (Map.fromList es') | es' <- shrink (Map.toList es)]

-- Bounds

-- | How far a generated coordinate reaches from the origin, on any one axis.
coordinate :: Gen Double
coordinate = choose (-100, 100)

-- | Three coordinates, the shape both a position and a quaternion's axis take.
coordinates :: Gen Vec3
coordinates = V3 <$> coordinate <*> coordinate <*> coordinate

{- | The squared length below which a quaternion is too short to normalize into
a meaningful rotation.
-}
degenerate :: Double
degenerate = 1e-3

unitRange :: (Double, Double)
unitRange = (0, 1)
