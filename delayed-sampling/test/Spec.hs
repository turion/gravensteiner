module Main where

import DelayedSampling qualified
import Record qualified
import Test.Hspec (hspec)

main :: IO ()
main = hspec $ do
  DelayedSampling.test
  Record.test
