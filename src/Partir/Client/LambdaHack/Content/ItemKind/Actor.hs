{-# LANGUAGE OverloadedStrings #-}

module Partir.Client.LambdaHack.Content.ItemKind.Actor
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
                                                ( Color(Brown, BrWhite) )
import           Game.LambdaHack.Definition.Defs
                                                ( CStore(COrgan) )
import           Game.LambdaHack.Definition.Flavour
                                                ( zipPlain )

content :: [ItemKind]
content = [warrior, thornbush]

warrior :: ItemKind
warrior = ItemKind
  { isymbol  = '@'
  , iname    = "warrior"
  , ifreq    = [("hero", 100), ("mobile", 1)]
  , iflavour = zipPlain [BrWhite]
  , icount   = 1
  , irarity  = [(1, 5)]
  , iverbHit = "thud"
  , iweight  = 80000
  , idamage  = 0
  , iaspects = [ AddSkill SkApply   2
               , AddSkill SkMaxCalm 70
               , AddSkill SkMaxHP   80
               , AddSkill SkNocto   2
               , AddSkill SkOdor    1
               , AddSkill SkProject 2
               , AddSkill SkSpeed   20
               , AddSkill SkWait    1
               , SetFlag Durable
               ]
  , ieffects = []
  , ikit     = [("fist", COrgan), ("foot", COrgan), ("eye 6", COrgan), ("ear 3", COrgan), ("sapient brain", COrgan)]
  , idesc    = "Homemade armour is just as good."
  }

thornbush :: ItemKind
thornbush = ItemKind
  { isymbol  = 't'
  , iname    = "thornbush"
  , ifreq    = [("animal", 20), ("immobile animal", 20)]
  , iflavour = zipPlain [Brown]
  , icount   = 1
  , irarity  = [(1, 13)]
  , iverbHit = "scrape"
  , iweight  = 80000
  , idamage  = 0
  , iaspects = [ AddSkill SkMaxHP   20
               , AddSkill SkMaxCalm 999
               , AddSkill SkSpeed   22
               , AddSkill SkNocto   2
               , AddSkill SkWait    1
               , AddSkill SkMelee   1
               , SetFlag Durable
               ]
  , ieffects = []
  , idesc    = "Each branch bears long, curved thorns."
  , ikit     = [("thorn", COrgan), ("bark", COrgan)]
  }
