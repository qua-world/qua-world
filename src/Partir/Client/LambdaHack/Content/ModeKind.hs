{-# LANGUAGE OverloadedStrings #-}

module Partir.Client.LambdaHack.Content.ModeKind
  ( content
  , makeData
  )
where

import           Game.LambdaHack.Content.ModeKind
                                                ( AutoLeader(..)
                                                , HiIndeterminant(..)
                                                , LeaderMode(..)
                                                , ModeKind(..)
                                                , Outcome(..)
                                                , Player(..)
                                                , Roster(..)
                                                , makeData
                                                )
import           Game.LambdaHack.Core.Prelude   ( (\\) )
import           Game.LambdaHack.Definition.Ability
                                                ( Tactic(..)
                                                , meleeAdjacent
                                                , zeroSkills
                                                )

content :: [ModeKind]
content = [raid, screensaverRaid]

raid :: ModeKind
raid = ModeKind
  { msymbol = 'r'
  , mname   = "solo raid (1)"
  , mfreq   = [("solo", 1), ("raid", 1), ("campaign scenario", 1)]
  , mroster = rosterRaid
  , mcaves  = [([-2], ["caveRaid"])]
  , mendMsg =
    [ ( Killed
      , "This expedition has gone wrong. However, scientific mind does not despair, but analyzes and corrects. Did you \
        \perchance awake one animal too many? Did you remember to try using all consumables at your disposal for your \
        \immediate survival? Did you choose a challenge with difficulty level within your means? Answer honestly, \
        \ponder wisely, experiment methodically."
      )
    , ( Defeated
      , "Regrettably, the other team snatched the grant, while you were busy contemplating natural phenomena. Science \
        \is a competitive sport, as sad as it sounds. It's not enough to make a discovery, you have to get there first."
      )
    , ( Escape
      , "You've got hold of the machine! Think of the hours of fun taking it apart and putting it back together again! \
        \That's a great first step on your quest to solve the typing problems of the world."
      )
    ]
  , mdesc   =
    "An incredibly advanced typing machine worth 100 gold is buried at the exit of this maze. Be the first to find it \
    \and fund a research team that makes typing accurate and dependable forever."
  }

screensaverRaid :: ModeKind
screensaverRaid = raid { mname   = "auto-raid (1)"
                       , mfreq   = [("insert coin", 1), ("no confirms", 1)]
                       , mroster = screensave (AutoLeader False False) rosterRaid
                       }
 where
  screensave :: AutoLeader -> Roster -> Roster
  screensave auto r =
    let f []                         = []
        f ((player, initial) : rest) = (player { fleaderMode = LeaderAI auto }, initial) : rest
    in  r { rosterList = f $ rosterList r }

rosterRaid :: Roster
rosterRaid = Roster
  { rosterList  = [ (playerHero { fhiCondPoly = hiHeroShort }                              , [(-2, 1, "hero")])
                  , (playerAntiHero { fname = "Indigo Founder", fhiCondPoly = hiHeroShort }, [(-2, 1, "hero")])
                  , ( playerAnimal  -- starting over escape
                    , [(-2, 2, "animal")]
                    )
                  , (playerHorror, [])
                  ]  -- for summoned monsters
  , rosterEnemy = [ ("Explorer"      , "Animal Kingdom")
                  , ("Explorer"      , "Horror Den")
                  , ("Indigo Founder", "Animal Kingdom")
                  , ("Indigo Founder", "Horror Den")
                  ]
  , rosterAlly  = []
  }
 where
  hiHeroShort =
    [ ([(HiLoot, 100)]   , [minBound, maxBound])
    , ([(HiConst, 100)]  , victoryOutcomes)
    , ([(HiSprint, -500)], victoryOutcomes)
    , ([(HiSurvival, 10)], [minBound .. maxBound] \\ victoryOutcomes)
    ]

playerHero :: Player
playerHero = Player { fname        = "Explorer"
                    , fgroups      = ["hero"]
                    , fskillsOther = meleeAdjacent
                    , fcanEscape   = True
                    , fneverEmpty  = True
                    , fhiCondPoly  = hiHeroLong
                    , fhasGender   = True
                    , ftactic      = TExplore
                    , fleaderMode  = LeaderUI $ AutoLeader False False
                    , fhasUI       = True
                    }

playerAntiHero :: Player
playerAntiHero = playerHero { fleaderMode = LeaderAI $ AutoLeader True False, fhasUI = False }

playerAnimal :: Player
playerAnimal = Player { fname        = "Animal Kingdom"
                      , fgroups      = ["animal", "mobile animal", "immobile animal", "scavenger"]
                      , fskillsOther = zeroSkills
                      , fcanEscape   = False
                      , fneverEmpty  = False
                      , fhiCondPoly  = hiDweller
                      , fhasGender   = False
                      , ftactic      = TRoam
                      , fleaderMode  = LeaderNull
                      , fhasUI       = False
                      }

playerHorror :: Player
playerHorror = Player { fname        = "Horror Den"
                      , fgroups      = ["horror"]
                      , fskillsOther = zeroSkills
                      , fcanEscape   = False
                      , fneverEmpty  = False
                      , fhiCondPoly  = []
                      , fhasGender   = False
                      , ftactic      = TPatrol
                      , fleaderMode  = LeaderNull
                      , fhasUI       = False
                      }

hiHeroLong :: [([(HiIndeterminant, Double)], [Outcome])]
hiHeroLong =
  [ ([(HiLoot, 10000)]   , [minBound .. maxBound])
  , ([(HiSprint, -20000)], victoryOutcomes)
  , ([(HiBlitz, -100)]   , victoryOutcomes)
  , ([(HiSurvival, 10)]  , [minBound .. maxBound] \\ victoryOutcomes)
  ]

hiDweller :: [([(HiIndeterminant, Double)], [Outcome])]
hiDweller =
  [ ([(HiConst, 1000)]               , victoryOutcomes)
  , ([(HiConst, 1000), (HiLoss, -10)], victoryOutcomes)
  , ([(HiSprint, -1000)]             , victoryOutcomes)
  , ([(HiBlitz, -100)]               , victoryOutcomes)
  , ([(HiSurvival, 100)]             , [minBound .. maxBound] \\ victoryOutcomes)
  ]

victoryOutcomes :: [Outcome]
victoryOutcomes = [Conquer, Escape]
