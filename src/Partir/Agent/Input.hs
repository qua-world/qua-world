-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

{- |
Module      : Partir.Agent.Input
Description : The intents an agent asks the world to carry out

An 'Intent' is what an agent asks for on a step, before the simulation decides
whether and when it happens. It is the unstamped counterpart of
"Partir.World.Event": an intent carries only what the agent chose, and the
simulation stamps the 'Partir.World.Types.Tick' and
'Partir.World.Types.AgentId' onto it to produce the event it applies.

Every participant speaks this one vocabulary, so the layers below never branch
on which kind of client produced an intent.
-}
module Partir.Agent.Input (
  Intent (..),
)
where

import Data.Text (Text)

import Partir.World.Types (EntityId, Quat, Vec3)

-- | A single request an agent makes of the world.
data Intent
  = -- | Move to an absolute position.
    Move Vec3
  | -- | Face an absolute orientation.
    Look Quat
  | -- | Interact with an entity.
    Interact EntityId
  | -- | Say something into the world.
    Speak Text
  | -- | Leave the world. Client-local: no event follows.
    Quit
  deriving (Eq, Show)
