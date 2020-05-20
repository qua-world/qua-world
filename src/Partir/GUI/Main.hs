module Main where

import qualified Partir                         ( someFunc )

main :: IO ()
main = do
  putStrLn "Hello, Haskell!"
  Partir.someFunc
