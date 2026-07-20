{-|
Module      : Partir.World.Scene
Description : The shared, pure scene and its event fold
Copyright   : (c) Alex Brandt, 2026
License     : MIT

A 'Scene' is the shared world state: the current 'Tick' and the set of live
entities. It evolves only through 'apply', which folds a single 'Event' into a
new scene. The representation is @IO@-free and total, so it is cheap to
property-test and reusable across every client and headless bot.
-}
module Partir.World.Scene
  ( Scene (..)
  , empty
  , apply
  , entityAt
  )
where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map

import Partir.World.Event (Event (..), eventTick)
import Partir.World.Types (EntityId, Pose (..), Tick (..))

-- | The shared world state at a point in simulation time.
data Scene = Scene
  { sceneTick :: Tick                  -- ^ The latest tick observed.
  , sceneEntities :: Map EntityId Pose -- ^ Each live entity's pose, by identifier.
  }
  deriving (Eq, Show)

-- | The scene before any event has occurred: tick zero, no entities.
empty :: Scene
empty = Scene (Tick 0) Map.empty

-- | Fold a single event into the scene, advancing its clock and mutating its
-- entities. The tick never decreases.
apply :: Event -> Scene -> Scene
apply e s = mutate e s {sceneTick = max (sceneTick s) (eventTick e)}

-- | Look up an entity's pose by identifier.
entityAt :: EntityId -> Scene -> Maybe Pose
entityAt eid = Map.lookup eid . sceneEntities

mutate :: Event -> Scene -> Scene
mutate (Spawn _ _ eid pos orient) = onEntities (Map.insert eid (Pose pos orient))
mutate (Despawn _ _ eid) = onEntities (Map.delete eid)
mutate (Move _ _ eid pos) = onEntities (Map.adjust (\p -> p {posePosition = pos}) eid)
mutate (Look _ _ eid orient) = onEntities (Map.adjust (\p -> p {poseOrientation = orient}) eid)
mutate (Speak _ _ _) = id
mutate (Interact _ _ _) = id

onEntities :: (Map EntityId Pose -> Map EntityId Pose) -> Scene -> Scene
onEntities f s = s {sceneEntities = f (sceneEntities s)}
