{- |
Module      : Partir.Agent.Observer
Description : The agent that watches the world and never acts on it
Copyright   : (c) Alex Brandt, 2026
License     : MIT

An 'Observer' takes part in the world without changing it: whatever scene it is
stepped against, it emits no 'Partir.Agent.Input.Intent'. It backs the @observe@
subcommand and is the base case of the 'Agent' class — a participant present in
the world, contributing nothing to it.
-}
module Partir.Agent.Observer (
  Observer (..),
)
where

import Partir.Agent.Class (Agent (..))

-- | A participant that only watches. Stateless.
data Observer = Observer
  deriving (Eq, Show)

instance Agent Observer where
  step _ observer = (observer, [])
