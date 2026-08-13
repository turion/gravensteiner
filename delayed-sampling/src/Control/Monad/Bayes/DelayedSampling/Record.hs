{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE UndecidableInstances #-}

{- | Sugar for records of delayed-sampling variables (R8), built on 'barbies'
  higher-kinded data: a record @b Distribution@ initializes to a record
  @b Variable@, which can then be partially observed against a record
  @b Observed@ or read out to a record @b Identity@.
-}
module Control.Monad.Bayes.DelayedSampling.Record (
  Observed (..),
  Basic,
  initializeRec,
  observeRec,
  valueRec,
) where

import Control.Monad (void)
import Control.Monad.Bayes.Class (MonadDistribution, MonadMeasure)
import Control.Monad.Bayes.DelayedSampling hiding (Const)
import Data.Functor.Barbie
import Data.Functor.Const (Const (..))
import Data.Functor.Identity (Identity (..))
import Data.Functor.Product (Product (..))
import Data.Typeable (Typeable)

{- | Whether a field of an observed record was actually measured: 'Observed'
  carries the value, 'NotObserved' means it wasn't.

  R12 distinguishes /why/ ('NotMentioned' vs 'NotMeasured'), since they take
  different paths in the likelihood; collapsed here for now because that
  needs a source class this module doesn't have yet — see
  @todo\/mention-vs-not-measured-deferred.md@.
-}
data Observed a = Observed a | NotObserved
  deriving (Show, Eq, Functor, Foldable, Traversable)

{- | The constraint 'initialize'\/'value'\/'observe' need on every field type,
  bundled into a single class so 'AllB' can quantify over it.
-}
class (Typeable a, Show a, Eq a) => Basic a
instance (Typeable a, Show a, Eq a) => Basic a

-- | Initialize a whole record of distributions at once.
initializeRec ::
  (TraversableB b, ConstraintsB b, AllB Basic b, Monad m) =>
  b Distribution ->
  DelayedSamplingT m (b Variable)
initializeRec = btraverseC @Basic initialize

-- | Force a whole record of variables to concrete values at once.
valueRec ::
  (TraversableB b, ConstraintsB b, AllB Basic b, MonadDistribution m) =>
  b Variable ->
  DelayedSamplingT m (b Identity)
valueRec = btraverseC @Basic (fmap Identity . value)

-- | Observe a whole record of variables at once, skipping unobserved fields.
observeRec ::
  (TraversableB b, ConstraintsB b, AllB Basic b, ApplicativeB b, MonadMeasure m) =>
  b Variable ->
  b Observed ->
  DelayedSamplingT m ()
observeRec vars obs = void $ btraverseC @Basic observeField (bprod vars obs)

observeField :: (Basic a, MonadMeasure m) => Product Variable Observed a -> DelayedSamplingT m (Const () a)
observeField (Pair v o) = do
  case o of
    Observed x -> observe v x
    NotObserved -> pure ()
  pure (Const ())
