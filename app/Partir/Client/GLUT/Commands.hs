module Partir.Client.GLUT.Commands (
  observe,
)
where

import Debug.Trace (traceIO)
import Options.Applicative

import Partir.Agent.Observer (Observer (..))

observe :: ParserInfo (IO ())
observe =
  info
    (pure (traceIO ("becoming " ++ show Observer)))
    (fullDesc <> progDesc "Become an observer in qua.world")
