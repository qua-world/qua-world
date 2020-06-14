{-# LANGUAGE OverloadedStrings #-}

module Partir.Client.LambdaHack.Content.ItemKind.Weapon
  ( content
  )
where

import           Game.LambdaHack.Content.ItemKind
                                                ( Aspect(..)
                                                , ItemKind(..)
                                                )
import qualified Game.LambdaHack.Content.RuleKind
                                               as RuleKind
                                                ( RuleContent(rsymbolProjectile) )
import           Game.LambdaHack.Core.Dice      ( d
                                                , dL
                                                )
import           Game.LambdaHack.Definition.Ability
                                                ( Skill(..) )
import           Game.LambdaHack.Definition.Color
                                                ( Color(BrRed) )
import           Game.LambdaHack.Definition.Flavour
                                                ( zipPlain )
import qualified Partir.Client.LambdaHack.Content.RuleKind
                                               as Content.RuleKind
                                                ( content )

content :: [ItemKind]
content = [dart]

dart :: ItemKind
dart = ItemKind { isymbol  = RuleKind.rsymbolProjectile Content.RuleKind.content
                , iname    = "dart"
                , ifreq    = [("common item", 100), ("any arrow", 50), ("weak arrow", 50)]
                , iflavour = zipPlain [BrRed]
                , icount   = 1 + 4 `dL` 5
                , irarity  = [(1, 15), (10, 5)]
                , iverbHit = "prick"
                , iweight  = 40
                , idamage  = 1 `d` 1
                , iaspects = [AddSkill SkHurtMelee $ (-15 + 1 `d` 2 + 1 `dL` 3) * 5]
                , ieffects = []
                , ikit     = []
                , idesc    = "A sharp delicate dart with fins."
                }
