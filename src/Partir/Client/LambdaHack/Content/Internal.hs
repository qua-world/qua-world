module Partir.Client.LambdaHack.Content.Internal
  ( caves
  , validateCaves
  , items
  , validateItems
  , modes
  , validateModes
  , places
  , validatePlaces
  , tiles
  , validateTiles
  )
where

import           Data.Text                      ( Text )
import qualified Game.LambdaHack.Content.CaveKind
                                               as LambdaHack.CaveKind
                                                ( CaveKind
                                                , validateAll
                                                )
import qualified Game.LambdaHack.Content.ItemKind
                                               as LambdaHack.ItemKind
                                                ( ItemKind
                                                , validateAll
                                                )
import qualified Game.LambdaHack.Content.ModeKind
                                               as LambdaHack.ModeKind
                                                ( ModeKind
                                                , validateAll
                                                )
import qualified Game.LambdaHack.Content.PlaceKind
                                               as LambdaHack.PlaceKind
                                                ( PlaceKind
                                                , validateAll
                                                )
import qualified Game.LambdaHack.Content.TileKind
                                               as LambdaHack.TileKind
                                                ( TileKind
                                                , validateAll
                                                )
import           Game.LambdaHack.Definition.ContentData
                                                ( ContentData )
import qualified Partir.Client.LambdaHack.Content.CaveKind
                                               as CaveKind
import qualified Partir.Client.LambdaHack.Content.ItemKind
                                               as ItemKind
import qualified Partir.Client.LambdaHack.Content.ModeKind
                                               as ModeKind
import qualified Partir.Client.LambdaHack.Content.PlaceKind
                                               as PlaceKind
import qualified Partir.Client.LambdaHack.Content.TileKind
                                               as TileKind

caves :: ContentData LambdaHack.CaveKind.CaveKind
caves = CaveKind.makeData items places tiles CaveKind.content

validateCaves :: [Text]
validateCaves = LambdaHack.CaveKind.validateAll items places tiles CaveKind.content caves

items :: ContentData LambdaHack.ItemKind.ItemKind
items = ItemKind.makeData ItemKind.content

validateItems :: [Text]
validateItems = LambdaHack.ItemKind.validateAll ItemKind.content items

modes :: ContentData LambdaHack.ModeKind.ModeKind
modes = ModeKind.makeData caves items ModeKind.content

validateModes :: [Text]
validateModes = LambdaHack.ModeKind.validateAll caves items ModeKind.content modes

places :: ContentData LambdaHack.PlaceKind.PlaceKind
places = PlaceKind.makeData tiles PlaceKind.content

validatePlaces :: [Text]
validatePlaces = LambdaHack.PlaceKind.validateAll tiles PlaceKind.content places

tiles :: ContentData LambdaHack.TileKind.TileKind
tiles = TileKind.makeData items TileKind.content

validateTiles :: [Text]
validateTiles = LambdaHack.TileKind.validateAll items TileKind.content tiles
