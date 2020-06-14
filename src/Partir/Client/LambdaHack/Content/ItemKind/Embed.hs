{-# LANGUAGE OverloadedStrings #-}

module Partir.Client.LambdaHack.Content.ItemKind.Embed
  ( content
  )
where

import           Game.LambdaHack.Core.Dice      ( d
                                                , dL
                                                )
import           Game.LambdaHack.Content.ItemKind
                                                ( Aspect(..)
                                                , DetectKind(..)
                                                , Effect(..)
                                                , ItemKind(..)
                                                , timerNone
                                                , toOrganBad
                                                , toOrganGood
                                                )
import           Game.LambdaHack.Definition.Ability
                                                ( Flag(..) )
import           Game.LambdaHack.Definition.Color
                                                ( Color(BrBlack, BrWhite, BrMagenta, BrYellow)
                                                , brightCol
                                                )
import           Game.LambdaHack.Definition.Defs
                                                ( CStore(CInv) )
import           Game.LambdaHack.Definition.Flavour
                                                ( zipPlain )

content :: [ItemKind]
content =
  [stairsUp, stairsDown, signboardExit, doorwayTrapTemplate, doorwayTrap, scratchOnWall, obscenePictogram, escape]

stairsUp :: ItemKind
stairsUp = ItemKind { isymbol  = '<'
                    , iname    = "flight"
                    , ifreq    = [("staircase up", 1)]
                    , iflavour = zipPlain [BrWhite]
                    , icount   = 1
                    , irarity  = [(1, 1)]
                    , iverbHit = "crash"
                    , iweight  = 100000
                    , idamage  = 0
                    , iaspects = [ELabel "of steps", SetFlag Durable]
                    , ieffects = [Ascend True]
                    , ikit     = []
                    , idesc    = "Stairs that rise towards escape."
                    }

stairsDown :: ItemKind
stairsDown = stairsUp { isymbol = '>', ifreq = [("staircase down", 1)], ieffects = [Ascend False], idesc = "" }

signboardExit :: ItemKind
signboardExit = ItemKind { isymbol  = '?'
                         , iname    = "inscription"
                         , ifreq    = [("signboard", 50)]
                         , iflavour = zipPlain [BrMagenta]
                         , icount   = 1
                         , irarity  = [(1, 1)]
                         , iverbHit = "whack"
                         , iweight  = 10000
                         , idamage  = 0
                         , iaspects = [SetFlag Durable]
                         , ieffects = [Detect DetectExit 100]
                         , idesc    = "Crude big arrows hastily carved by unknown hands."
                         , ikit     = []
                         }

doorwayTrapTemplate :: ItemKind
doorwayTrapTemplate = ItemKind { isymbol  = '+'
                               , iname    = "doorway trap"
                               , ifreq    = [("doorway trap unknown", 1)]
                               , iflavour = zipPlain brightCol
                               , icount   = 1
                               , irarity  = [(1, 1)]
                               , iverbHit = "cirpple"
                               , iweight  = 10000
                               , idamage  = 0
                               , iaspects = [HideAs "doorway trap unknown"]
                               , ieffects = []
                               , idesc    = "Just turn the handle…"
                               , ikit     = []
                               }

doorwayTrap :: ItemKind
doorwayTrap = doorwayTrapTemplate { ifreq = [("doorway trap", 50)], ieffects = [toOrganBad "blind" $ (1 `dL` 4) * 5] }

scratchOnWall :: ItemKind
scratchOnWall = ItemKind { isymbol  = '?'
                         , iname    = "claw mark"
                         , ifreq    = [("scratch on wall", 1)]
                         , iflavour = zipPlain [BrBlack]
                         , icount   = 1
                         , irarity  = [(1, 1)]
                         , iverbHit = "scratch"
                         , iweight  = 1000
                         , idamage  = 0
                         , iaspects = [SetFlag Durable]
                         , ieffects = [VerbMsg "start making sense of the scratches", Detect DetectHidden 3]
                         , idesc    = "A seemingly random series of scratches, carved deep into the wall."
                         , ikit     = []
                         }

obscenePictogram :: ItemKind
obscenePictogram = ItemKind
  { isymbol  = '*'
  , iname    = "obscene pictogram"
  , ifreq    = [("obscene pictogram", 1)]
  , iflavour = zipPlain [BrMagenta]
  , icount   = 1
  , irarity  = [(1, 1)]
  , iverbHit = "infuriate"
  , iweight  = 1000
  , idamage  = 0
  , iaspects = [Timeout 7, SetFlag Durable]
  , ieffects = [ VerbMsg "enter destructive rage at the sight of an obscene pictogram"
               , RefillCalm (-20)
               , OneOf [toOrganGood "strengthened" (3 + 1 `d` 2), CreateItem CInv "sandstone rock" timerNone]
               ]
  , idesc    = "It's not even anatomically possible."
  , ikit     = []
  }

escape :: ItemKind
escape = stairsUp { isymbol  = 'E'
                  , iname    = "way"
                  , ifreq    = [("escape", 1)]
                  , iflavour = zipPlain [BrYellow]
                  , iaspects = [SetFlag Durable]
                  , ieffects = [Escape]
                  , idesc    = "May this nightmare have an end?"
                  }
