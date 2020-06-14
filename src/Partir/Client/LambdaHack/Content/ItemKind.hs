module Partir.Client.LambdaHack.Content.ItemKind
  ( content
  , makeData
  )
where

import           Game.LambdaHack.Content.ItemKind
                                                ( ItemKind(..)
                                                , makeData
                                                )
import qualified Partir.Client.LambdaHack.Content.ItemKind.Actor
                                               as Actor
                                                ( content )
import qualified Partir.Client.LambdaHack.Content.ItemKind.Animal
                                               as Animal
                                                ( content )
import qualified Partir.Client.LambdaHack.Content.ItemKind.Condition
                                               as Condition
                                                ( content )
import qualified Partir.Client.LambdaHack.Content.ItemKind.Currency
                                               as Currency
                                                ( content )
import qualified Partir.Client.LambdaHack.Content.ItemKind.Embed
                                               as Embed
                                                ( content )
import qualified Partir.Client.LambdaHack.Content.ItemKind.Monster
                                               as Monster
                                                ( content )
import qualified Partir.Client.LambdaHack.Content.ItemKind.Organ
                                               as Organ
                                                ( content )
import qualified Partir.Client.LambdaHack.Content.ItemKind.Potion
                                               as Potion
                                                ( content )
import qualified Partir.Client.LambdaHack.Content.ItemKind.Weapon
                                               as Weapon
                                                ( content )

content :: [ItemKind]
content = concat
  [ Actor.content
  , Animal.content
  , Condition.content
  , Currency.content
  , Embed.content
  , Monster.content
  , Organ.content
  , Potion.content
  , Weapon.content
  ]
