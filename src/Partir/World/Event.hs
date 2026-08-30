{- |
Module      : Partir.World.Event
Description : Events produced by agents to mutate the shared scene
Copyright   : (c) Alex Brandt, 2026
License     : MIT

An 'Event' is the sole vocabulary by which agents change the world. Every event
is stamped with the 'Tick' at which it occurs and the 'AgentId' that produced
it, following the agent-produces-event decomposition of a multi-user 3D system.
Events are @IO@-free values; "Partir.World.Scene" folds them into a scene.
-}
module Partir.World.Event (
  Event (..),
  eventTick,
  eventAgent,
)
where

import Data.Text (Text)

import Partir.World.Types (AgentId, EntityId, Quat, Tick, Vec3)

-- | A single change requested by an agent at a given tick.
data Event
  = -- | Bring an entity into existence at a position and orientation.
    Spawn Tick AgentId EntityId Vec3 Quat
  | -- | Remove an entity from the scene.
    Despawn Tick AgentId EntityId
  | -- | Reposition an existing entity.
    Move Tick AgentId EntityId Vec3
  | -- | Reorient an existing entity.
    Look Tick AgentId EntityId Quat
  | -- | Emit an utterance into the world.
    Speak Tick AgentId Text
  | -- | Interact with a target entity.
    Interact Tick AgentId EntityId
  deriving (Eq, Show)

-- | The tick at which an event occurs.
eventTick :: Event -> Tick
eventTick (Spawn t _ _ _ _) = t
eventTick (Despawn t _ _) = t
eventTick (Move t _ _ _) = t
eventTick (Look t _ _ _) = t
eventTick (Speak t _ _) = t
eventTick (Interact t _ _) = t

-- | The agent that produced an event.
eventAgent :: Event -> AgentId
eventAgent (Spawn _ a _ _ _) = a
eventAgent (Despawn _ a _) = a
eventAgent (Move _ a _ _) = a
eventAgent (Look _ a _ _) = a
eventAgent (Speak _ a _) = a
eventAgent (Interact _ a _) = a
