module Partir.Client.GLUT.Commands
  ( observe
  )
where

import           Options.Applicative

observe :: ParserInfo (IO ())
observe = info (pure observe') (fullDesc <> progDesc "Become an observer in qua.world") where observe' = return ()
