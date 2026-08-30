{- |
Module      : Partir.Agent.Observer
Description : An agent that watches the world without acting on it
Copyright   : (c) Alex Brandt, 2026
License     : MIT

An 'Observer' takes part in the world without changing it: whatever scene it is
stepped against, it emits no 'Partir.Agent.Input.Intent'.
-}
module Partir.Agent.Observer (
  Observer (..),
)
where

import Partir.Agent.Class (Agent (..))

-- | A participant that only watches.
data Observer = Observer
  deriving (Eq, Show)

instance Agent Observer where
  step _ observer = (observer, [])
