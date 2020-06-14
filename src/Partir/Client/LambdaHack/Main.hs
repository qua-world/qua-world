module Main where

import qualified Game.LambdaHack.Client        as LambdaHack
                                                ( mkUIOptions )
import qualified Game.LambdaHack.Client.UI.ContentClientUI
                                               as LambdaHack
                                                ( emptyCCUI )
import qualified Game.LambdaHack.Server        as LambdaHack
                                                ( serverOptionsPI )
import qualified Implementation.MonadServerImplementation
                                               as LambdaHack
                                                ( executorSer )
import           Options.Applicative            ( execParser )
import           Partir.Client.LambdaHack.Content
                                                ( content )

main :: IO ()
main = do
  serverOptions <- execParser LambdaHack.serverOptionsPI
  uiOptions     <- LambdaHack.mkUIOptions content False
  LambdaHack.executorSer content LambdaHack.emptyCCUI serverOptions uiOptions
