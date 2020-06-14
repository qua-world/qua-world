{-# LANGUAGE OverloadedStrings #-}

module Partir.Client.LambdaHack.Content.ItemKind.Organ
  ( content
  )
where

import           Game.LambdaHack.Core.Dice      ( d )
import           Game.LambdaHack.Content.ItemKind
                                                ( Aspect(..)
                                                , Effect(..)
                                                , ItemKind(..)
                                                )
import           Game.LambdaHack.Definition.Ability
                                                ( Flag(..)
                                                , Skill(..)
                                                )
import           Game.LambdaHack.Definition.Color
                                                ( Color(Red) )
import           Game.LambdaHack.Definition.Defs
                                                ( CStore(COrgan) )
import           Game.LambdaHack.Definition.Flavour
                                                ( zipPlain )

content :: [ItemKind]
content = [fist, foot, smallJaw, lash, pupil, thorn]

fist :: ItemKind
fist = ItemKind { isymbol  = ','
                , iname    = "fist"
                , ifreq    = [("fist", 100)]
                , iflavour = zipPlain [Red]
                , icount   = 2
                , irarity  = [(1, 1)]
                , iverbHit = "punch"
                , iweight  = 2000
                , idamage  = 4 `d` 1
                , iaspects = [SetFlag Durable, SetFlag Meleeable]
                , ieffects = []
                , ikit     = []
                , idesc    = "Simple but effective."
                }

foot :: ItemKind
foot = fist { iname    = "foot"
            , ifreq    = [("foot", 50)]
            , iverbHit = "kick"
            , idamage  = 4 `d` 1
            , idesc    = "A weapon you can still use if disarmed."
            }

smallJaw :: ItemKind
smallJaw = fist { iname    = "small jaw"
                , ifreq    = [("small jaw", 20)]
                , icount   = 1
                , iverbHit = "rip"
                , idamage  = 3 `d` 1
                , idesc    = "Filled with samll, even teeth."
                }

lash :: ItemKind
lash = fist { iname = "lash", ifreq = [("lash", 100)], icount = 1, iverbHit = "lash", idamage = 3 `d` 1, idesc = "" }

pupil :: ItemKind
pupil = fist { iname    = "pupil"
             , ifreq    = [("pupil", 100)]
             , icount   = 1
             , iverbHit = "gaze at"
             , idamage  = 1 `d` 1
             , iaspects = [AddSkill SkSight 12, Timeout 12] ++ iaspects fist
             , ieffects = [DropItem 1 maxBound COrgan "condition", RefillCalm (-10)]
             , idesc    = ""
             }

thorn :: ItemKind
thorn = fist { iname    = "thorn"
             , ifreq    = [("thorn", 100)]
             , icount   = 2 + 1 `d` 3
             , iverbHit = "puncture"
             , idamage  = 2 `d` 1
             , iaspects = [SetFlag Meleeable]  -- not Durable
             , ieffects = [VerbNoLonger "be not so thorny any more"]
             , idesc    = "Sharp yet brittle."
             }
