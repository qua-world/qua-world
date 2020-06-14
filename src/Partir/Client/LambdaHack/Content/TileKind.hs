{-# LANGUAGE OverloadedStrings #-}

module Partir.Client.LambdaHack.Content.TileKind
  ( content
  , makeData
  )
where

import           Game.LambdaHack.Content.TileKind
                                                ( Feature(..)
                                                , TileKind(..)
                                                , makeData
                                                , talterForStairs
                                                )
import           Game.LambdaHack.Definition.Color
                                                ( Color(..)
                                                , defFG
                                                )

content :: [TileKind]
content =
  unknown -- Must be first and the only talter 1.
    : [ basicOuterFence
      , bedrock
      , doorClosed
      , doorClosedH
      , doorOpen
      , doorOpenH
      , doorTrapped
      , doorTrappedH
      , escapeUp
      , floorCorridor
      , floorCorridorDark
      , signboardRead
      , signboardUnread
      , stairsDown
      , stairsUp
      , unknownOuterFence
      , wall
      , wallH
      , wallObscured
      , wallObscuredDefacedH
      , wallSuspect
      , wallSuspectH
      ]

unknown :: TileKind
unknown = TileKind { tsymbol  = ' '
                   , tname    = "unknown space"
                   , tfreq    = [("unknown space", 1)]
                   , tcolor   = defFG
                   , tcolor2  = defFG
                   , talter   = 1
                   , tfeature = [Dark]
                   }

basicOuterFence :: TileKind
basicOuterFence = TileKind { tsymbol  = ' '
                           , tname    = "impenetrable bedrock"
                           , tfreq    = [("basic outer fence", 1)]
                           , tcolor   = defFG
                           , tcolor2  = defFG
                           , talter   = maxBound
                           , tfeature = [Dark]
                           }

bedrock :: TileKind
bedrock = TileKind { tsymbol  = ' '
                   , tname    = "bedrock"
                   , tfreq    = [("fillerWall", 1), ("legendLit", 100), ("legendDark", 100)]
                   , tcolor   = defFG
                   , tcolor2  = defFG
                   , talter   = 100
                   , tfeature = [Dark]
                   }

doorClosed :: TileKind
doorClosed = TileKind { tsymbol  = '+'
                      , tname    = "closed door"
                      , tfreq    = [("closed vertical door Lit", 1)]
                      , tcolor   = Brown
                      , tcolor2  = BrBlack
                      , talter   = 2
                      , tfeature = [OpenTo "open vertical door Lit"]
                      }

doorClosedH :: TileKind
doorClosedH = TileKind { tsymbol  = '+'
                       , tname    = "closed door"
                       , tfreq    = [("closed horizontal door Lit", 1)]
                       , tcolor   = Brown
                       , tcolor2  = BrBlack
                       , talter   = 2
                       , tfeature = [OpenTo "open horizontal door Lit"]
                       }

doorOpen :: TileKind
doorOpen = TileKind { tsymbol  = '-'
                    , tname    = "open door"
                    , tfreq    = [("open vertical door Lit", 1)]
                    , tcolor   = Brown
                    , tcolor2  = BrBlack
                    , talter   = 4
                    , tfeature = [Walkable, Clear, NoItem, NoActor, CloseTo "closed vertical door Lit"]
                    }

doorOpenH :: TileKind
doorOpenH = TileKind { tsymbol  = '|'
                     , tname    = "open door"
                     , tfreq    = [("open horizontal door Lit", 1)]
                     , tcolor   = Brown
                     , tcolor2  = BrBlack
                     , talter   = 4
                     , tfeature = [Walkable, Clear, NoItem, NoActor, CloseTo "closed horizontal door Lit"]
                     }

doorTrapped :: TileKind
doorTrapped = TileKind
  { tsymbol  = '+'
  , tname    = "trapped door"
  , tfreq    = [("trapped vertical door Lit", 1)]
  , tcolor   = BrRed
  , tcolor2  = Red
  , talter   = 2
  , tfeature = [Embed "doorway trap", OpenTo "open vertical door Lit", HideAs "suspect vertical wall Lit"]
  }

doorTrappedH :: TileKind
doorTrappedH = TileKind
  { tsymbol  = '+'
  , tname    = "trapped door"
  , tfreq    = [("trapped horizontal door Lit", 1)]
  , tcolor   = BrRed
  , tcolor2  = Red
  , talter   = 2
  , tfeature = [Embed "doorway trap", OpenTo "open horizontal door Lit", HideAs "suspect horizontal wall Lit"]
  }

escapeUp :: TileKind
escapeUp = TileKind { tsymbol  = '<'
                    , tname    = "exit hatch up"
                    , tfreq    = [("legendLit", 1), ("legendDark", 1), ("escape up", 1)]
                    , tcolor   = BrYellow
                    , tcolor2  = BrYellow
                    , talter   = 0
                    , tfeature = [Embed "escape", ConsideredByAI]
                    }

floorCorridor :: TileKind
floorCorridor = TileKind { tsymbol  = '#'
                         , tname    = "corridor"
                         , tfreq    = [("floorCorridorLit", 1)]
                         , tcolor   = BrWhite
                         , tcolor2  = defFG
                         , talter   = 0
                         , tfeature = [Walkable, Clear]
                         }

floorCorridorDark :: TileKind
floorCorridorDark = TileKind { tsymbol  = '#'
                             , tname    = "corridor"
                             , tfreq    = [("floorCorridorDark", 1)]
                             , tcolor   = BrWhite
                             , tcolor2  = defFG
                             , talter   = 0
                             , tfeature = [Walkable, Clear]
                             }

signboardRead :: TileKind
signboardRead = TileKind { tsymbol  = '0'
                         , tname    = "signboard"
                         , tfreq    = [("signboard", 1), ("escapeSetDark", 1)]
                         , tcolor   = BrCyan
                         , tcolor2  = Cyan
                         , talter   = 5
                         , tfeature = [Embed "signboard", HideAs "signboard unread"]
                         }

signboardUnread :: TileKind
signboardUnread = TileKind { tsymbol  = '0'
                           , tname    = "signboard"
                           , tfreq    = [("signboard unread", 1)]
                           , tcolor   = BrCyan
                           , tcolor2  = Cyan
                           , talter   = 5
                           , tfeature = [ConsideredByAI, RevealAs "signboard"]
                           }

stairsDown :: TileKind
stairsDown = TileKind { tsymbol  = '>'
                      , tname    = "staircase down"
                      , tfreq    = [("staircase down", 9), ("ordinary staircase down", 1)]
                      , tcolor   = BrWhite
                      , tcolor2  = defFG
                      , talter   = talterForStairs
                      , tfeature = [Embed "staircase down", ConsideredByAI]
                      }

stairsUp :: TileKind
stairsUp = TileKind { tsymbol  = '<'
                    , tname    = "staircase up"
                    , tfreq    = [("staircase up", 9), ("ordinary staircase up", 1)]
                    , tcolor   = BrWhite
                    , tcolor2  = defFG
                    , talter   = talterForStairs
                    , tfeature = [Embed "staircase up", ConsideredByAI]
                    }

unknownOuterFence :: TileKind
unknownOuterFence = TileKind { tsymbol  = ' '
                             , tname    = "unknown space"
                             , tfreq    = [("unknown outer fence", 1)]
                             , tcolor   = defFG
                             , tcolor2  = defFG
                             , talter   = maxBound
                             , tfeature = [Dark]
                             }

wall :: TileKind
wall = TileKind { tsymbol  = '|'
                , tname    = "granite wall"
                , tfreq    = [("legendLit", 100), ("wall Lit", 100), ("rectWindowsOver_!_Lit", 80)]
                , tcolor   = BrWhite
                , tcolor2  = defFG
                , talter   = 100
                , tfeature = [BuildAs "suspect vertical wall Lit"]
                }

wallH :: TileKind
wallH = TileKind { tsymbol  = '-'
                 , tname    = "sandstone wall"
                 , tfreq    = [("legendLit", 100), ("wallH Lit", 100), ("rectWindowsOver_=_Lit", 80)]
                 , tcolor   = BrWhite
                 , tcolor2  = defFG
                 , talter   = 100
                 , tfeature = [BuildAs "suspect horizontal wall Lit"]
                 }

wallObscured :: TileKind
wallObscured = TileKind { tsymbol  = '|'
                        , tname    = "scratched wall"
                        , tfreq    = [("obscured vertical wall Lit", 1)]
                        , tcolor   = BrWhite
                        , tcolor2  = defFG
                        , talter   = 5
                        , tfeature = [Embed "scratch on wall", HideAs "suspect vertical wall Lit"]
                        }

wallObscuredDefacedH :: TileKind
wallObscuredDefacedH = TileKind { tsymbol  = '-'
                                , tname    = "defaced wall"
                                , tfreq    = [("obscured horizontal wall Lit", 90)]
                                , tcolor   = BrWhite
                                , tcolor2  = defFG
                                , talter   = 5
                                , tfeature = [Embed "obscene pictogram", HideAs "suspect horizontal wall Lit"]
                                }

wallSuspect :: TileKind
wallSuspect = TileKind { tsymbol  = '|'
                       , tname    = "suspect uneven wall"
                       , tfreq    = [("suspect vertical wall Lit", 1)]
                       , tcolor   = BrWhite
                       , tcolor2  = defFG
                       , talter   = 2
                       , tfeature = [RevealAs "trapped vertical door Lit", ObscureAs "obscured vertical wall Lit"]
                       }

wallSuspectH :: TileKind
wallSuspectH = TileKind { tsymbol  = '-'
                        , tname    = "suspect painted wall"
                        , tfreq    = [("suspect horizontal wall Lit", 1)]
                        , tcolor   = BrWhite
                        , tcolor2  = defFG
                        , talter   = 2
                        , tfeature = [RevealAs "trapped horizontal door Lit", ObscureAs "obscured horizontal wall Lit"]
                        }
