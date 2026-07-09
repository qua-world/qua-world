{-|
Module      : Partir.World.Types
Description : Scalar identifiers and spatial aliases for the world model
Copyright   : (c) Alex Brandt, 2026
License     : MIT

Foundational, @IO@-free types shared across the @Partir.World.*@ domain: opaque
identifiers for agents, entities, and simulation ticks, plus aliases for the
positional and rotational vectors supplied by "Linear".
-}
module Partir.World.Types
  ( AgentId (..)
  , EntityId (..)
  , Tick (..)
  , Vec3
  , Quat
  )
where

import Data.Word (Word64)
import Linear.Quaternion (Quaternion)
import Linear.V3 (V3)

-- | Identifies an agent: a producer of 'Partir.World.Event.Event's.
newtype AgentId = AgentId Word64
  deriving (Eq, Ord, Show)

-- | Identifies an entity present in a 'Partir.World.Scene.Scene'.
newtype EntityId = EntityId Word64
  deriving (Eq, Ord, Show)

-- | A discrete simulation instant. Monotonically non-decreasing as events apply.
newtype Tick = Tick Word64
  deriving (Eq, Ord, Show)

-- | A position or displacement in world space.
type Vec3 = V3 Double

-- | An orientation in world space.
type Quat = Quaternion Double
