-- SPDX-FileCopyrightText: 2020 Alex Brandt
--
-- SPDX-License-Identifier: MIT

module Partir.Client.GLUT.Commands (
  observe,
)
where

import Debug.Trace (traceIO)
import Options.Applicative

import Partir.Agent.Null (Null (..))

observe :: ParserInfo (IO ())
observe =
  info
    (pure (traceIO ("agent: " ++ show Null)))
    (fullDesc <> progDesc "Become an observer in qua.world")
