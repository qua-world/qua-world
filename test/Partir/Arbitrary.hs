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
'Double's or an event sequence hundreds long.
-}
module Partir.Arbitrary (
  Position (..),
  Sheet (..),
  UnitQuat (..),
  Window (..),
  orderedBelow,
  shrinkOrderedBelow,
)
where

import qualified Data.Map.Strict as Map
import Data.Text (pack, unpack)
import qualified Data.Vector as Vector
import Linear.Metric (normalize, quadrance)
import Linear.Quaternion (Quaternion (..))
import Linear.V2 (V2 (..))
import Linear.V3 (V3 (..))
import Test.QuickCheck (
  Arbitrary (arbitrary, shrink),
  Gen,
  Positive (..),
  choose,
  frequency,
  oneof,
  resize,
  suchThat,
  vectorOf,
 )

import Partir.Asset.Sprite (Grid (..))
import Partir.Asset.Tilemap (
  Placement (..),
  TileLayer (..),
  Tilemap (..),
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

  -- 'shrink' on a 'Double' only ever reduces magnitude, so a shrunk coordinate
  -- stays inside a bound centred on zero.
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

{- | A sheet waiting to be cut: the cell, and the pixel size of the sheet it is
cut from.

Every extent reaches below one, so a property sees the sheets that hold no
whole cell alongside those that do. Cells are drawn from a smaller range than
sheets, which leaves most draws with frames to inspect.
-}
data Sheet = Sheet
  { sheetGrid :: Grid
  , sheetWidth :: Int
  , sheetHeight :: Int
  }
  deriving (Eq, Show)

instance Arbitrary Sheet where
  arbitrary = Sheet <$> (Grid <$> cellExtent <*> cellExtent) <*> sheetExtent <*> sheetExtent

  shrink (Sheet (Grid frameWidth frameHeight) width height) =
    [ Sheet (Grid frameWidth' frameHeight') width' height'
    | (frameWidth', frameHeight', width', height') <-
        shrink (frameWidth, frameHeight, width, height)
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
draws instead biases the upper toward the top, starving whichever partition
sits at the bottom of the range.
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

{- | A layer whose cell vector matches the grid it declares.
'Partir.Asset.Tilemap.toMesh' reads a cell's column and row out of the
declared width, so a generator that let the two drift would test a shape no
loader produces.

Shrinking drops whole rows off the bottom and shrinks tiles in place;
dropping cells alone would break that agreement.
-}
instance Arbitrary TileLayer where
  arbitrary = do
    columns <- choose (0, gridEdge)
    rows <- choose (0, gridEdge)
    name <- pack <$> arbitrary
    cells <- vectorOf (columns * rows) tile
    pure (TileLayer name columns rows (Vector.fromList cells))
   where
    tile = frequency [(1, pure Nothing), (3, Just . getPositive <$> arbitrary)]

  shrink layer =
    [ layer
        { tileLayerRows = rows
        , tileLayerTiles = Vector.take (tileLayerColumns layer * rows) cells
        }
    | rows <- shrink (tileLayerRows layer)
    ]
      <> [ layer{tileLayerTiles = Vector.fromList shrunk}
         | shrunk <- shrink (Vector.toList cells)
         , length shrunk == Vector.length cells
         ]
   where
    cells = tileLayerTiles layer

instance Arbitrary Placement where
  arbitrary = Placement . pack <$> arbitrary <*> tiles <*> tiles
   where
    tiles = V2 <$> coordinate <*> coordinate

  shrink (Placement n (V2 ox oy) (V2 sx sy)) =
    [ Placement (pack n') (V2 ox' oy') (V2 sx' sy')
    | (n', (ox', oy'), (sx', sy')) <- shrink (unpack n, (ox, oy), (sx, sy))
    ]

{- | A map whose declared grid covers every layer on it, which is what each
loader derives from its source document.
-}
instance Arbitrary Tilemap where
  arbitrary = do
    layers <- resize layerCount arbitrary
    placements <- resize layerCount arbitrary
    pure
      Tilemap
        { tilemapColumns = extent tileLayerColumns layers
        , tilemapRows = extent tileLayerRows layers
        , tilemapLayers = layers
        , tilemapPlacements = placements
        }

  shrink tilemap =
    [ tilemap
        { tilemapLayers = layers
        , tilemapColumns = extent tileLayerColumns layers
        , tilemapRows = extent tileLayerRows layers
        }
    | layers <- shrink (tilemapLayers tilemap)
    ]
      <> [tilemap{tilemapPlacements = ps} | ps <- shrink (tilemapPlacements tilemap)]

-- | The grid a tilemap needs to hold every one of its layers.
extent :: (TileLayer -> Int) -> [TileLayer] -> Int
extent cells = maximum . (0 :) . map cells

-- Bounds

-- | How far a generated coordinate reaches from the origin, on any one axis.
coordinate :: Gen Double
coordinate = choose (-100, 100)

-- | The pixel extents a 'Sheet' and its cell are drawn from.
cellExtent, sheetExtent :: Gen Int
cellExtent = choose (-2, 8)
sheetExtent = choose (-4, 32)

-- | Three coordinates, the shape both a position and a quaternion's axis take.
coordinates :: Gen Vec3
coordinates = V3 <$> coordinate <*> coordinate <*> coordinate

{- | The squared length below which a quaternion is too short to normalize into
a meaningful rotation.
-}
degenerate :: Double
degenerate = 1e-3

{- | How far a generated tile layer reaches on either axis. The geometry a
tilemap builds is four vertices per filled cell, so an unbounded grid spends
the run allocating rather than covering cases.
-}
gridEdge :: Int
gridEdge = 8

-- | How many layers, and how many placements, a generated tilemap carries.
layerCount :: Int
layerCount = 3

unitRange :: (Double, Double)
unitRange = (0, 1)
