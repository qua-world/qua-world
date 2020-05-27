module Main where

import           Options.Applicative            ( (<**>)
                                                , ParserInfo
                                                , execParser
                                                , fullDesc
                                                , helper
                                                , info
                                                , progDesc
                                                )
import           Partir.Client.LambdaHack.Options
                                                ( Options(Options) )
import           Partir.Client.LambdaHack.Game  ( game )

main :: IO ()
main = execParser options >>= game

options :: ParserInfo Options
options = info (options' <**> helper) (fullDesc <> progDesc "Qua World LambdaHack Client")
  where options' = pure Options
