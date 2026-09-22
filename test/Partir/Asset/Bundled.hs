-- SPDX-FileCopyrightText: 2026 Alex Brandt
--
-- SPDX-License-Identifier: MIT

-- | Loading the package's own example assets, for the specs that assert on one.
module Partir.Asset.Bundled (
  bundled,
)
where

import System.OsPath (OsPath, encodeFS)
import Test.Tasty.HUnit (assertFailure)

import Paths_partir_qua_world (getDataFileName)

-- | Load a bundled asset, failing the test case with the load error.
bundled :: Show e => FilePath -> (OsPath -> IO (Either e a)) -> IO a
bundled name load = getDataFileName name >>= encodeFS >>= load >>= either (assertFailure . show) pure
