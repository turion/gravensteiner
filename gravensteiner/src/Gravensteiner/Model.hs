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

    observer :: p UUID
  {- ^ The 'Person' (keyed into 'Database''s @people@) who observed the fruit and recorded its
  properties. Often this will be the same as the pomologist who made the judgement, but not always.
  -}
  , -- TODO: photographs of the fruit
    uuid :: UUID
  }

data Collection p = Collection
  { fruits :: [Fruit p]
  , date :: p Day
  -- ^ The date the collection was made
  , tree :: UUID
  -- ^ Keyed into 'Observations''s @trees@
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

{- | A claim that a tree is a particular cultivar, together with how much to trust it.

'Judgement' is the /only/ mechanism for asserting cultivar identity, and is deliberately not
restricted to a pomologist inspecting fruit: a nursery's planting record and a gene test result
are judgements too, not ground truth recorded some other way. Nurseries mislabel stock, and even
a gene test carries a small but non-negligible risk of laboratory error (e.g. mixing up two
samples) — every source of identity is fallible.
-}
data Judgement p = Judgement
  { pomologist :: UUID
  {- ^ Keyed into 'Database''s @people@. Whoever or whatever made the judgement — a pomologist
  examining fruit, a nursery attributing stock at planting, a lab reporting a gene test.
  -- TODO: a nursery is a legal person, not a 'Person', and its evidence is not a 'Fruit'
  collection but e.g. a grafting lineage; 'Judgement' cannot yet represent that distinction.
  -}
  , tree :: UUID
  , cultivar :: UUID
  -- ^ The cultivar the pomologist judges the tree to be
  , collection :: p UUID
  -- ^ The collection that was used to make this judgement, if any (e.g. absent for a gene test)
  , certainty :: p Interval
  -- ^ The probability the judgement's maker would bet on this judgement being correct.
  --   This self-information is their own subjective probability, not a probability derived from the data in the database.
  , date :: p Day
  , uuid :: UUID
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
