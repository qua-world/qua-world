{-# LANGUAGE OverloadedStrings #-}

module Partir.Client.LambdaHack.Content.ItemKind.Monster
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
                                                ( Color(BrRed) )
import           Game.LambdaHack.Definition.Defs
                                                ( CStore(COrgan) )
import           Game.LambdaHack.Definition.Flavour
                                                ( zipPlain )

content :: [ItemKind]
content = [eye]

eye :: ItemKind
eye = ItemKind
  { isymbol  = 'e'
  , iname    = "eye"
  , ifreq    = [("monster", 100), ("mobile", 1), ("mobile monster", 100), ("scout monster", 10)]
  , iflavour = zipPlain [BrRed]
  , icount   = 1
  , irarity  = [(3, 0), (4, 10), (10, 8)]
  , iverbHit = "thud"
  , iweight  = 80000
  , idamage  = 0
  , iaspects = [ AddSkill SkAggression 1
               , AddSkill SkApply      1
               , AddSkill SkMaxCalm    70
               , AddSkill SkMaxHP      16
               , AddSkill SkNocto      2
               , AddSkill SkProject    2
               , AddSkill SkSpeed      20
               , SetFlag Durable
               ]
  , ieffects = []
  , ikit     = [("lash", COrgan), ("pupil", COrgan), ("sapient brain", COrgan)]
  , idesc    =
    "Under your stare, it reduces to the bits that define its essence. Under introspection, the bits slow down and solidify into an arbitrary form again. It must be huge inside, for holographic principle to manifest so overtly."
  }
