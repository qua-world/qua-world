module Partir.Client.LambdaHack.Content
  ( content
  )
where

import           Game.LambdaHack.Common.Kind    ( COps(..)
                                                , emptyItemSpeedup
                                                , emptyTileSpeedup
                                                )
import           Partir.Client.LambdaHack.Content.Internal
import qualified Partir.Client.LambdaHack.Content.RuleKind
                                               as RuleKind
                                                ( content )

content :: COps
content = COps { cocave        = caves
               , coitem        = items
               , comode        = modes
               , coplace       = places
               , corule        = RuleKind.content
               , cotile        = tiles
               , coItemSpeedup = emptyItemSpeedup
               , coTileSpeedup = emptyTileSpeedup
               }
