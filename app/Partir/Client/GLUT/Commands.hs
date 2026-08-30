module Partir.Client.GLUT.Commands (
  observe,
)
where

import Options.Applicative

import Partir.Agent.Observer (Observer (..))

observe :: ParserInfo (IO ())
observe = info (pure (become Observer)) (fullDesc <> progDesc "Become an observer in qua.world")

{- | Take up the given agent. Stepping it needs a scene to perceive, which
arrives over the network (#12) and is driven by the simulation loop (#15).
-}
become :: Observer -> IO ()
become Observer = return ()
