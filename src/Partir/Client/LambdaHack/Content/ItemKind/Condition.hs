{-# LANGUAGE OverloadedStrings #-}

module Partir.Client.LambdaHack.Content.ItemKind.Condition
  ( content
  )
where

import           Game.LambdaHack.Core.Dice      ( intToDice )
import           Game.LambdaHack.Content.ItemKind
                                                ( Aspect(..)
                                                , Effect(..)
                                                , ItemKind(..)
                                                , verbMsgLess
                                                , verbMsgNoLonger
                                                )
import           Game.LambdaHack.Definition.Ability
                                                ( Flag(..)
                                                , Skill(..)
                                                )
import           Game.LambdaHack.Definition.Color
                                                ( Color(BrBlue, BrGreen, BrRed, BrWhite, Red) )
import           Game.LambdaHack.Definition.Flavour
                                                ( zipPlain )

content :: [ItemKind]
content =
  [ armoredSkin
  , impressed
  , bonusHP
  , braced
  , asleep
  , eye6
  , ear3
  , ear8
  , sapientBrain
  , nostril
  , animalBrain
  , tmpBlind
  , bark
  ]

armoredSkin :: ItemKind
armoredSkin = ItemKind { isymbol  = ','
                       , iname    = "armored skin"
                       , ifreq    = [("armored skin", 1)]
                       , iflavour = zipPlain [Red]
                       , icount   = 1
                       , irarity  = [(1, 1)]
                       , iverbHit = "bash"
                       , iweight  = 2000
                       , idamage  = 0
                       , iaspects = [AddSkill SkArmorMelee 30, AddSkill SkArmorRanged 15, SetFlag Durable]
                       , ieffects = []
                       , ikit     = []
                       , idesc    = "Homemade armour is just as good."
                       }

impressed :: ItemKind
impressed = armoredSkin
  { isymbol  = 'I'
  , iname    = "impressed"
  , ifreq    = [("impressed", 1), ("condition", 1)]
  , iflavour = zipPlain [BrRed]
  , iverbHit = "confuse"
  , iweight  = 0
  , iaspects = [AddSkill SkMaxCalm (-1), SetFlag Fragile, SetFlag Condition]
  , ieffects = [OnSmash $ verbMsgLess "impressed", OnSmash $ verbMsgNoLonger "impressed"]
  , idesc    =
    "Being impressed by one's adversary sounds like fun, but on battlefield it equals treason. Almost.  Throw in depleted battle calm and it leads to mindless desertion outright."
  }

-- TODO Status?
bonusHP :: ItemKind
bonusHP = armoredSkin
  { isymbol  = 'H'
  , iname    = "bonus HP"
  , ifreq    = [("bonus HP", 1)]
  , iflavour = zipPlain [BrBlue]
  , iverbHit = "intimidate"
  , iweight  = 0
  , iaspects = [AddSkill SkMaxHP 1]
  , idesc    =
    "Growing up in a privileged background gave you the training and the discrete garment accessories that improve your posture and resilience."
  }

braced :: ItemKind
braced = armoredSkin
  { isymbol  = 'B'
  , iname    = "braced"
  , ifreq    = [("braced", 1)]
  , iflavour = zipPlain [BrGreen]
  , iverbHit = "brace"
  , iweight  = 0
  , iaspects = [AddSkill SkArmorMelee 50, AddSkill SkArmorRanged 25, AddSkill SkHearing 10, SetFlag Condition]
  , idesc    =
    "Apart of increased resilience to attacks, being braced protects from displacement by foes and other forms of forced translocation, e.g., pushing or pulling."
  }

asleep :: ItemKind
asleep = armoredSkin
  { isymbol  = 'S'
  , iname    = "asleep"
  , ifreq    = [("asleep", 1)]
  , iflavour = zipPlain [BrGreen]
  , icount   = 5
  , iverbHit = "slay"
  , iweight  = 0
  , iaspects = (flip AddSkill (-1) <$> [SkMove .. SkApply])
                 ++ [ AddSkill SkMelee      1
                    , AddSkill SkAlter      1
                    , AddSkill SkWait       1
                    , AddSkill SkSight      (-3)
                    , AddSkill SkArmorMelee (-10)
                    , SetFlag Condition
                    ]
  , idesc    =
    "Sleep helps to regain health, albeit extremely slowly. Being asleep makes you vulnerable, with gradually diminishing effects as the slumber wears off over several turns. Any non-idle action, not only combat but even yawning or stretching removes a sizable portion of the sleepiness."
  }

-- TODO Organ
eye6 :: ItemKind
eye6 = armoredSkin { iname    = "eye"
                   , ifreq    = [("eye 6", 1)]
                   , icount   = 2
                   , iverbHit = "glare at"
                   , iaspects = [AddSkill SkSight (intToDice 6), SetFlag Durable]
                   , idesc    = "A piercing stare."
                   }

-- TODO Organ
ear3 :: ItemKind
ear3 = armoredSkin { iname    = "ear"
                   , ifreq    = [("ear 3", 1)]
                   , icount   = 2
                   , iverbHit = "overhear"
                   , iaspects = [AddSkill SkHearing (intToDice 3), SetFlag Durable]
                   , idesc    = ""
                   }

-- TODO Organ
ear8 :: ItemKind
ear8 = ear3 { ifreq = [("ear 8", 1)], iaspects = [AddSkill SkHearing (intToDice 8), SetFlag Durable] }

-- TODO Organ
sapientBrain :: ItemKind
sapientBrain = armoredSkin
  { iname    = "sapient brain"
  , ifreq    = [("sapient brain", 1)]
  , iverbHit = "outbrain"
  , iaspects = (flip AddSkill 1 <$> [SkMove .. SkApply])
                 ++ [AddSkill SkMove 4, AddSkill SkAlter 4, AddSkill SkWait 2, AddSkill SkApply 1, SetFlag Durable]
  , idesc    = ""
  }

-- TODO Organ
nostril :: ItemKind
nostril = armoredSkin { iname    = "nostril"
                      , ifreq    = [("nostril", 100)]
                      , icount   = 2
                      , iverbHit = "snuff"
                      , iaspects = [AddSkill SkSmell 1, SetFlag Durable]
                      , idesc    = ""
                      }

-- TODO Organ
animalBrain :: ItemKind
animalBrain = armoredSkin
  { iname    = "animal brain"
  , ifreq    = [("animal brain", 100)]
  , iverbHit = "blank"
  , iaspects = (flip AddSkill 1 <$> [SkMove .. SkApply])
                 ++ [ AddSkill SkMove     4
                    , AddSkill SkAlter    2
                    , AddSkill SkWait     2
                    , AddSkill SkDisplace (-1)
                    , AddSkill SkMoveItem (-1)
                    , AddSkill SkProject  (-1)
                    , SetFlag Durable
                    ]
  , idesc    = ""
  }

tmpBlind :: ItemKind
tmpBlind = ItemKind
  { isymbol  = '+'
  , iname    = "blind"
  , ifreq    = [("blind", 1), ("condition", 1)]
  , iflavour = zipPlain [BrWhite]
  , icount   = 1
  , irarity  = [(1, 1)]
  , iverbHit = "affect"
  , iweight  = 0
  , idamage  = 0
  , iaspects = [AddSkill SkSight (-99), SetFlag Periodic, SetFlag Fragile, SetFlag Condition]
  , ieffects = [OnSmash $ verbMsgLess "blind", OnSmash $ verbMsgNoLonger "blind", verbMsgNoLonger "blind"]
  , idesc    = ""
  , ikit     = []
  }

bark :: ItemKind
bark = armoredSkin { iname = "bark", ifreq = [("bark", 100)], idesc = "" }
