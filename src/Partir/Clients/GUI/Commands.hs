module Partir.Clients.GUI.Commands
  ( observe
  )
where

import           Options.Applicative

observe :: ParserInfo (IO ())
observe = info (pure observe') (fullDesc <> progDesc "Become an observer in qua.world") where observe' = return ()
