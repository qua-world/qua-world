{-# LANGUAGE OverloadedStrings #-}

module Partir.Client.LambdaHack.Content.ItemKind.Potion
  ( content
  )
where

import           Game.LambdaHack.Content.ItemKind
                                                ( Aspect(..)
                                                , Effect(..)
                                                , ItemKind(..)
                                                , toVelocity
                                                )
import           Game.LambdaHack.Core.Dice      ( dL )
import           Game.LambdaHack.Core.Prelude   ( maxBound )
import           Game.LambdaHack.Definition.Ability
                                                ( Flag(..) )
import           Game.LambdaHack.Definition.Color
                                                ( brightCol )
import           Game.LambdaHack.Definition.Defs
                                                ( CStore(..) )
import           Game.LambdaHack.Definition.Flavour
                                                ( zipFancy
                                                , zipLiquid
                                                , zipPlain
                                                )

content :: [ItemKind]
content = [unknownPotion, healingPotion]

unknownPotion :: ItemKind
unknownPotion = ItemKind { isymbol  = '!'
                         , iname    = "potion"
                         , ifreq    = [("potion unknown", 1)]
                         , iflavour = zipLiquid brightCol ++ zipPlain brightCol ++ zipFancy brightCol
                         , icount   = 1 `dL` 3
                         , irarity  = [(1, 10), (10, 6)]
                         , iverbHit = "splash"
                         , iweight  = 200
                         , idamage  = 0
                         , iaspects = [HideAs "potion unknown", SetFlag Lobable, SetFlag Fragile, toVelocity 50]
                         , ieffects = []
                         , ikit     = []
                         , idesc    = "A vial of bright, frothing concoction.  The best that nature has to offer."
                         }

healingPotion :: ItemKind
healingPotion = unknownPotion
  { ifreq    = [("common items", 100), ("potion", 100), ("any vial", 100)]
  , irarity  = [(1, 10), (10, 10)]
  , iaspects = ELabel "of healing" : iaspects unknownPotion
  , ieffects = [RefillHP 10, DropItem maxBound maxBound COrgan "condition", OnSmash (Explode "healing mist 2")] -- TODO What is DropItem doing?
  }
