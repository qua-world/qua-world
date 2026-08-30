{- |
Module      : Partir.Agent.Null
Description : The agent that takes part in the world without acting on it
Copyright   : (c) Alex Brandt, 2026
License     : MIT

'Null' is the base case of the 'Agent' class: whatever scene it is stepped
against, it emits no 'Partir.Agent.Input.Intent'. It stands in wherever the
class needs a participant and nothing should act.
-}
module Partir.Agent.Null (
  Null (..),
)
where

import Partir.Agent.Class (Agent (..))

-- | A participant that never acts.
data Null = Null
  deriving (Eq, Show)

instance Agent Null where
  step _ agent = (agent, [])
