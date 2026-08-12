module Main where

import DelayedSampling qualified
import Test.Hspec (hspec)

main :: IO ()
main = hspec DelayedSampling.test
