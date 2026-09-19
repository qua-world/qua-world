-- tasty-discover scans every module under test/ for `test_`, `prop_`, and
-- `unit_` bindings. A module's export list still gates them, so a new binding
-- that is not exported fails to compile as "not in scope" from this driver
-- rather than being silently skipped.
--
-- Without --tree-display every discovered group sits at the top level, so the
-- module a group came from is lost and bare names like "apply" collide.
{-# OPTIONS_GHC -F -pgmF tasty-discover -optF --tree-display #-}
