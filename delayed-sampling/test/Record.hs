{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}

module Record where

import Control.Monad (void)
import Control.Monad.Bayes.DelayedSampling
import Control.Monad.Bayes.DelayedSampling.Record
import Control.Monad.Bayes.Sampler.Strict
import Control.Monad.Bayes.Weighted (runWeightedT)
import Data.Functor.Barbie
import DelayedSampling (checked, shouldBeRight)
import GHC.Generics (Generic)
import Test.Hspec

{- | A synthetic record of two independent scalar features, standing in for
something like @Fruit@'s appearance fields.
-}
data TestRecord f = TestRecord
  { fieldA :: f Double
  , fieldB :: f Double
  }
  deriving stock (Generic)
  deriving anyclass (FunctorB, TraversableB, ApplicativeB, ConstraintsB)

distributions :: TestRecord Distribution
distributions = TestRecord (Normal (Const 0) (Const 1)) (Normal (Const 10) (Const 2))

test :: SpecWith ()
test = describe "Record" $ do
  it "observing with a field NotObserved matches observing only the other field" $ do
    (resultRec, pRec) <- sampleIO $ runWeightedT $ evalDelayedSamplingT $ do
      vars <- initializeRec distributions
      checked $ observeRec vars (TestRecord (Observed 1) NotObserved)
    (resultSingle, pSingle) <- sampleIO $ runWeightedT $ evalDelayedSamplingT $ do
      vars <- initializeRec distributions
      checked $ observe (fieldA vars) 1
    void $ shouldBeRight resultRec
    void $ shouldBeRight resultSingle
    pRec `shouldBe` pSingle
