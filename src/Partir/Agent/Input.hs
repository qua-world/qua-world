{- |
Module      : Partir.Agent.Input
Description : The vocabulary an agent uses to ask the world for something
Copyright   : (c) Alex Brandt, 2026
License     : MIT

An 'Intent' is what an agent asks for on a step, before the simulation decides
whether and when it happens. It is the unstamped counterpart of
"Partir.World.Event": an intent carries only what the agent chose, and the
simulation stamps the 'Partir.World.Types.Tick' and
'Partir.World.Types.AgentId' onto it to produce the event it applies.

Every participant speaks this one vocabulary, so the simulation and networking
layers never branch on which kind of client produced an intent.
-}
module Partir.Agent.Input (
  Intent (..),
)
where

import Data.Text (Text)

import Partir.World.Types (EntityId, Quat, Vec3)

-- | A single request an agent makes of the world.
data Intent
  = -- | Move to a position.
    Move Vec3
  | -- | Face an orientation.
    Look Quat
  | -- | Interact with a target entity.
    Interact EntityId
  | -- | Say something into the world.
    Speak Text
  | -- | Leave the world. Client-local: it stamps no event.
    Quit
  deriving (Eq, Show)
