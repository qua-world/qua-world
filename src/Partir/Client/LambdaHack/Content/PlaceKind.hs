{-# LANGUAGE OverloadedStrings #-}

module Partir.Client.LambdaHack.Content.PlaceKind
  ( content
  , makeData
  )
where

import           Game.LambdaHack.Content.PlaceKind
                                                ( Cover(..)
                                                , Fence(..)
                                                , PlaceKind(..)
                                                , makeData
                                                )
content :: [PlaceKind]
content = [rect, staircase, staircase5, staircase25, escapeUp]

rect :: PlaceKind
rect = PlaceKind { psymbol       = 'r'
                 , pname         = "a chamber"
                 , pfreq         = [("rogue", 30), ("laboratory", 10)]
                 , prarity       = [(1, 10), (10, 6)]
                 , pcover        = CStretch
                 , pfence        = FNone
                 , ptopLeft      = ["--", "|·"]
                 , poverrideDark = []
                 , poverrideLit  = []
                 }

staircase :: PlaceKind
staircase = PlaceKind
  { psymbol       = '/'
  , pname         = "a staircase"
  , pfreq         = [("tiny staircase", 1)]
  , prarity       = [(1, 100), (10, 100)]
  , pcover        = CVerbatim
  , pfence        = FGround
  , ptopLeft      = ["<·>"]
  , poverrideDark = [ ('<', "staircase up")
                    , ('>', "staircase down")
                    , ('I', "signboard")
                    , ('|', "wall Lit")
                    , ('-', "wallH Lit")
                    ]
  , poverrideLit  = [ ('<', "staircase up")
                    , ('>', "staircase down")
                    , ('I', "signboard")
                    , ('|', "wall Lit")
                    , ('-', "wallH Lit")
                    ]
  }

staircase5 :: PlaceKind
staircase5 =
  staircase { pfreq = [("open staircase", 200)], pfence = FGround, ptopLeft = ["0·0", "···", "<·>", "···", "0·0"] }

staircase25 :: PlaceKind
staircase25 = staircase { pfreq    = [("walled staircase", 50)]
                        , pfence   = FNone
                        , ptopLeft = ["---------", "|·······|", "|··<·>··|", "|·······|", "---------"]
                        }

escapeUp :: PlaceKind
escapeUp = PlaceKind { psymbol       = '<'
                     , pname         = "an escape up"
                     , pfreq         = [("escape up", 1)]
                     , prarity       = [(1, 1)]
                     , pcover        = CVerbatim
                     , pfence        = FGround
                     , ptopLeft      = [">"]
                     , poverrideDark = [('>', "escape up"), ('|', "wall Lit"), ('-', "wallH Lit")]
                     , poverrideLit  = [('>', "escape up"), ('|', "wall Lit"), ('-', "wallH Lit")]
                     }
