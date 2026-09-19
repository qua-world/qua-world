-- --tree-display nests each group under its module. Without it the groups
-- flatten, and a bare name like `apply` no longer says where it came from.
{-# OPTIONS_GHC -F -pgmF tasty-discover -optF --tree-display #-}
