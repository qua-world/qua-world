{- |
Module      : Partir.Agent.Class
Description : The one abstraction every participant in the world implements
Copyright   : (c) Alex Brandt, 2026
License     : MIT

A player, a bot, and an NPC all take part in the world the same way: each
perceives it and emits 'Intent's. 'Agent' is that shared abstraction, following
the uniform agent decomposition of a massively multi-user environment, so the
layers beneath treat every participant alike.

'step' is pure and total, so an agent is exercised without a window, a socket,
or a clock; drawing the world and carrying out the intents belongs to the
caller.
-}
module Partir.Agent.Class (
  Agent (..),
  WorldView,
)
where

import Partir.Agent.Input (Intent)
import Partir.World.Scene (Scene)

{- | What an agent perceives when it is stepped: the whole 'Scene'. #16 narrows
this to the entities within the agent's area of interest.
-}
type WorldView = Scene

-- | A participant in the world: it perceives, it decides, it emits.
class Agent a where
  {- | Advance the agent by one step against what it perceives, yielding its
  next state and the intents it wants carried out.
  -}
  step :: WorldView -> a -> (a, [Intent])
