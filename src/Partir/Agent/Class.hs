{- |
Module      : Partir.Agent.Class
Description : The abstraction every participant in the world implements
Copyright   : (c) Alex Brandt, 2026
License     : MIT

A player, a bot, and an NPC all take part in the world the same way: each
perceives it and emits 'Intent's. 'Agent' is that shared abstraction.

'step' is pure and total, so testing an agent needs no window, socket, or
clock; drawing the world and carrying out the intents belongs to the caller.
-}
module Partir.Agent.Class (
  Agent (..),
  WorldView,
)
where

import Partir.Agent.Input (Intent)
import Partir.World.Scene (Scene)

{- | What an agent perceives when stepped: the whole 'Scene'. #16 narrows it to
the agent's area of interest.
-}
type WorldView = Scene

-- | A participant in the world: it perceives, it decides, it emits.
class Agent a where
  -- | The state the agent carries forward, and what it asks the world for.
  step :: WorldView -> a -> (a, [Intent])
