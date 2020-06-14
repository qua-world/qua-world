{-# LANGUAGE OverloadedStrings #-}

module Partir.Client.LambdaHack.Content.CaveKind
  ( content
  , makeData
  )
where

import           Data.Ratio                     ( (%) )
import           Game.LambdaHack.Content.CaveKind
                                                ( CaveKind(..)
                                                , makeData
                                                )
import           Game.LambdaHack.Core.Dice      ( DiceXY(DiceXY)
                                                , d
                                                , dL
                                                )

content :: [CaveKind]
content = [rogue, raid]

rogue :: CaveKind
rogue = CaveKind { csymbol         = 'R'
                 , cname           = "A maze of twisty passages"
                 , cfreq           = [("default random", 100), ("caveRogue", 1)]  -- N.B., default random is required.
                 , cXminSize       = 80
                 , cYminSize       = 21
                 , ccellSize       = DiceXY (2 `d` 4 + 10) 6
                 , cminPlaceSize   = DiceXY (2 `d` 2 + 4) 5
                 , cmaxPlaceSize   = DiceXY 16 40
                 , cdarkOdds       = 1 `d` 54 + 1 `dL` 20 -- most rooms lit, to compensate for dark corridors
                 , cnightOdds      = 51  -- always night
                 , cauxConnects    = 1 % 2
                 , cmaxVoid        = 1 % 6
                 , cminStairDist   = 20
                 , cextraStairs    = 1 + 1 `d` 2
                 , cdoorChance     = 3 % 4
                 , copenChance     = 1 % 5
                 , chidden         = 7
                 , cactorCoeff     = 65  -- the maze requires time to explore
                 , cactorFreq      = [("monster", 60), ("animal", 40)]
                 , citemNum        = 6 `d` 5 + 10 - 10 `dL` 1  -- deep down quality over quantity
                 , citemFreq       = [("common item", 40), ("treasure", 60)]
                 , cplaceFreq      = [("rogue", 1)]
                 , cpassable       = False
                 , labyrinth       = False
                 , cdefTile        = "fillerWall"
                 , cdarkCorTile    = "floorCorridorDark"
                 , clitCorTile     = "floorCorridorLit"
                 , cwallTile       = "fillerWall"
                 , ccornerTile     = "fillerWall"
                 , cfenceTileN     = "basic outer fence"
                 , cfenceTileE     = "basic outer fence"
                 , cfenceTileS     = "basic outer fence"
                 , cfenceTileW     = "basic outer fence"
                 , cfenceApart     = False
                 , clegendDarkTile = "legendDark"
                 , clegendLitTile  = "legendLit"
                 , cescapeFreq     = []
                 , cstairFreq      = [("walled staircase", 50), ("open staircase", 50), ("tiny staircase", 1)]
                 , cstairAllowed   = []
                 , cdesc           = "Winding tunnels stretch into the dark."
                 }

raid :: CaveKind
raid = rogue { csymbol       = 'T'
             , cname         = "Typing den"
             , cfreq         = [("caveRaid", 1)]
             , cXminSize     = 50
             , cYminSize     = 21
             , ccellSize     = DiceXY (2 `d` 4 + 6) 6
             , cminPlaceSize = DiceXY (2 `d` 2 + 4) 5
             , cmaxPlaceSize = DiceXY 16 20
             , cdarkOdds     = 0
             , cmaxVoid      = 1 % 10
             , cextraStairs  = 0
             , cactorCoeff   = 250
             , cactorFreq    = [("animal", 100)]
             , citemNum      = 6 `d` 6
             , citemFreq     = [("common item", 100), ("currency", 500)]
             , cescapeFreq   = [("escape up", 1)]
             , cstairFreq    = []
             , cdesc         = ""
             }
