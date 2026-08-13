{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedRecordDot #-}

{- | Some types are tagged with a higher kinded datatype phase that can be used to mark parts of the data as being "not observed" via 'Maybe'.
Sampling data on the other hand will always produce data, so can use 'Identity' as the phase.
-}
module Gravensteiner.Model where

-- uuid
import Data.UUID (UUID)

-- text
import Data.Text (Text)

-- time
import Data.Time (Day, Year)

-- containers
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map

-- indexed-traversable
import Data.Foldable.WithIndex (FoldableWithIndex)
import Data.Functor.WithIndex (FunctorWithIndex)
import Data.Traversable.WithIndex (TraversableWithIndex (..))

-- ghc
import GHC.Records (HasField)

-- | Recorded in serialisation to allow for future migrations
version :: Int
version = 1

data Person = Person
  { name :: Text
  , email :: Maybe Text
  , phone :: Maybe Text
  , uuid :: UUID
  }

-- | A number assumed to be between 0 and 1
newtype Interval = Interval {getInterval :: Double}
  deriving (Show, Eq, Ord, Num, Fractional, Floating)

data Colours = Colours
  { yellow :: Interval
  , red :: Interval
  , green :: Interval
  }
  deriving (Show, Eq)

data Fruit p = Fruit
  { colours :: p Colours
  , russet :: p Interval
  , -- TODO Further properties to be added here, such as size, shape, etc.

    observer :: p Person
  {- ^ The person who observed the fruit and recorded its properties.
  Often this will be the same as the pomologist who made the judgement, but not always.
  -}
  , -- TODO: photographs of the fruit
    uuid :: UUID
  }

data Collection p = Collection
  { fruits :: [Fruit p]
  , date :: p Day
  -- ^ The date the collection was made
  , tree :: Tree p
  , uuid :: UUID
  }

data Tree p = Tree
  { planted :: p Year
  , uuid :: UUID
  }

data Cultivar = Cultivar
  { name :: Text
  , alternativeNames :: [Text]
  , uuid :: UUID
  }

data Judgement p = Judgement
  { pomologist :: Person
  , tree :: UUID
  , collection :: p UUID
  -- ^ The collection that was used to make this judgement
  , certainty :: Interval
  -- ^ The probability the pomologist would bet on this judgement being correct.
  , date :: p Day
  }

newtype UUIDMap a = UUIDMap {getUUIDMap :: Map UUID a}
  deriving newtype (Show, Eq, Functor, Foldable, FunctorWithIndex UUID, FoldableWithIndex UUID)
  deriving stock (Traversable)

instance TraversableWithIndex UUID UUIDMap where
  itraverse f (UUIDMap m) = UUIDMap <$> itraverse f m

insert :: (HasField "uuid" a UUID) => a -> UUIDMap a -> UUIDMap a
insert a (UUIDMap m) = UUIDMap $ Map.insert a.uuid a m

data Observations = Observations
  { collections :: UUIDMap (Collection Maybe)
  , trees :: UUIDMap (Tree Maybe)
  , judgements :: UUIDMap (Judgement Maybe)
  }

data Database = Database
  { people :: UUIDMap Person
  , cultivars :: UUIDMap Cultivar
  , observations :: Observations
  }
