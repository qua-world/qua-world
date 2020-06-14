{-# LANGUAGE OverloadedStrings #-}

module Partir.Client.LambdaHack.Content.ItemKind.Animal
  ( content
  )
where

import           Game.LambdaHack.Content.ItemKind
                                                ( Aspect(..)
                                                , ItemKind(..)
                                                )
import           Game.LambdaHack.Definition.Ability
                                                ( Flag(..)
                                                , Skill(..)
                                                )
import           Game.LambdaHack.Definition.Color
                                                ( Color(BrYellow) )
import           Game.LambdaHack.Definition.Defs
                                                ( CStore(COrgan) )
import           Game.LambdaHack.Definition.Flavour
                                                ( zipPlain )

content :: [ItemKind]
content = [goldenJackal]

goldenJackal :: ItemKind
goldenJackal = ItemKind
  { isymbol  = 'j'
  , iname    = "golden jackal"
  , ifreq    = [("animal", 100), ("mobile", 1), ("mobile animal", 100), ("scavenger", 50)]
  , iflavour = zipPlain [BrYellow]
  , icount   = 1
  , irarity  = [(1, 4), (10, 2)]
  , iverbHit = "thud"
  , iweight  = 13000
  , idamage  = 0
  , iaspects = [AddSkill SkMaxCalm 70, AddSkill SkMaxHP 15, AddSkill SkSpeed 24, AddSkill SkNocto 2, SetFlag Durable]
  , ieffects = []
  , ikit = [("small jaw", COrgan), ("nostril", COrgan), ("eye 6", COrgan), ("ear 8", COrgan), ("animal brain", COrgan)]
  , idesc    = "An opportunistic predator, feeding on carrion and the weak."
  }
