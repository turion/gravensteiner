module Main where

import Scale qualified
import Test.Hspec (hspec)

main :: IO ()
main = hspec $ do
  Scale.test
