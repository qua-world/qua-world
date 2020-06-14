module Partir.Client.LambdaHack.Content.RuleKind
  ( content
  )
where

import           Game.LambdaHack.Content.RuleKind
                                                ( RuleContent(..)
                                                , emptyRuleContent
                                                , makeData
                                                )

content :: RuleContent
content = makeData $ emptyRuleContent { rsymbolProjectile = '|' }
