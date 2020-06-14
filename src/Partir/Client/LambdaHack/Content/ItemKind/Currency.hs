{-# LANGUAGE OverloadedStrings #-}

module Partir.Client.LambdaHack.Content.ItemKind.Currency
  ( content
  )
where

import           Game.LambdaHack.Core.Dice      ( d
                                                , dL
                                                )
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
import           Game.LambdaHack.Definition.Flavour
                                                ( zipPlain )

content :: [ItemKind]
content = [unknownCurrency, currency]

unknownCurrency :: ItemKind
unknownCurrency = ItemKind { isymbol  = '$'
                           , iname    = "gold piece"
                           , ifreq    = [("currency unknown", 1), ("valuable", 1)]
                           , iflavour = zipPlain [BrYellow]
                           , icount   = 10 + 1 `d` 20 + 1 `dL` 20
                           , irarity  = [(1, 25), (10, 10)]
                           , iverbHit = "tap"
                           , iweight  = 31
                           , idamage  = 0
                           , iaspects = [HideAs "currency unknown", SetFlag Precious]
                           , ieffects = []
                           , ikit     = []
                           , idesc    = "Reliably valuable in every civilized plane of existence."
                           }

currency :: ItemKind
currency = unknownCurrency { ifreq    = [("treasure", 100), ("currency", 100), ("valuable", 1)]
                           , iaspects = iaspects unknownCurrency ++ [AddSkill SkShine 1, AddSkill SkSpeed (-1)]
                           }

