{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE NoImplicitPrelude #-}

{- | Some types are tagged with a higher kinded datatype phase that can be used to mark parts of the data as being "not observed" via 'Maybe' or 'Observed'.
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
import GHC.Generics (Generic)
import GHC.Records (HasField)

-- barbies
import Data.Functor.Barbie

-- dimensional
import Numeric.Units.Dimensional.Prelude

-- delayed-sampling
import Control.Monad.Bayes.DelayedSampling.Record (Observed (..))

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
  deriving stock (Show, Eq, Ord)
  deriving newtype (Num, Fractional, Floating)

data Colours = Colours
  { yellow :: Interval
  , red :: Interval
  , green :: Interval
  }
  deriving (Show, Eq)

-- | Measurable large-scale shape of a fruit.
data Shape p = Shape
  { height :: p (Length Double)
  {- ^ Taken at the tallest point of the flesh, not the polar axis through the stalk cavity and calyx basin, per UPOV TG/14
  characteristic 23. Units come from "Numeric.Units.Dimensional.SIUnits" via the re-exporting prelude, e.g. @58 *~ milli metre@.
  -}
  , diameter :: p (Length Double)
  {- ^ Taken at the widest point, the fruit's equator (UPOV TG/14 characteristic 24); "maximum" here
  names the caliper site, not a maximum over repeated measurements. E.g. @71 *~ milli metre@.
  -}
  }
  deriving stock (Generic)
  deriving anyclass (FunctorB, TraversableB, ApplicativeB, ConstraintsB)

{- | The ratio of height to diameter can be computed from the shape, which is a useful descriptor
for comparing cultivars. It is a function rather than a stored field because a stored ratio would
be a deterministic function of the two stored measurements, and a likelihood treating all three as
conditionally independent given the cultivar's parameters would count shape evidence twice.

To apply this to a recorded @Shape Observed@, first convert with
@bmap (\\o -> case o of Observed a -> Just a; NotObserved -> Nothing) s@ to get a @Shape Maybe@;
a partially measured fruit then yields 'Nothing' rather than a type error.
-}
heightDiameterRatio :: (Functor p, Applicative p) => Shape p -> p (Dimensionless Double)
heightDiameterRatio s = (/) <$> s.height <*> s.diameter

-- | Everything that can be directly observed about a fruit
data Appearance p = Appearance
  { colours :: p Colours
  , russet :: p Interval
  , shape :: Shape p
  , weight :: p (Mass Double)
  -- ^ The whole fruit, weighed on a kitchen scale. Example: @142 *~ gram@.
  }
  deriving stock (Generic)
  deriving anyclass (FunctorB, TraversableB, ApplicativeB, ConstraintsB)

-- Note: no 'ApplicativeB' here -- 'bpure' would need a 'Monoid UUID' for the plain @uuid@
-- field, which doesn't exist (and shouldn't: a UUID has no sensible "empty" value).
data Fruit p = Fruit
  { appearance :: Appearance p
  , observer :: p UUID
  {- ^ The 'Person' (keyed into 'Database''s @people@) who observed the fruit and recorded its
  properties. Often this will be the same as the pomologist who made the judgement, but not always.
  -}
  , -- TODO: photographs of the fruit
    uuid :: UUID
  }
  deriving stock (Generic)
  deriving anyclass (FunctorB, TraversableB, ConstraintsB)

-- Note: no 'ApplicativeB'/'ConstraintsB' -- the generic deriving doesn't reach through a
-- list-of-barbies field (@fruits :: [Fruit p]@).
data Collection p = Collection
  { fruits :: [Fruit p]
  , date :: p Day
  -- ^ The date the collection was made
  , tree :: UUID
  -- ^ Keyed into 'Observations''s @trees@
  , uuid :: UUID
  }
  deriving stock (Generic)
  deriving anyclass (FunctorB, TraversableB)

data Tree p = Tree
  { planted :: p Year
  , uuid :: UUID
  }
  deriving stock (Generic)
  deriving anyclass (FunctorB, TraversableB, ConstraintsB)

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
  {- ^ The probability the judgement's maker would bet on this judgement being correct.
  This self-information is their own subjective probability, not a probability derived from the data in the database.
  -}
  , date :: p Day
  , uuid :: UUID
  }
  deriving stock (Generic)
  deriving anyclass (FunctorB, TraversableB, ConstraintsB)

{- | How confident a description is about the location of a stated value, and optionally
its spread — e.g. a monograph saying a cultivar is "usually deep red, sometimes striped".
-}
data Elicited a = Elicited
  { location :: a
  , strength :: Double
  , spread :: Maybe (Spread a)
  }

data Spread a = Spread
  { scale :: a
  , scaleStrength :: Double
  }

-- | Whether a 'Description' stated a value for a field at all.
data Described a = DescribedAs (Elicited a) | NotDescribed

-- | Where a 'Description' comes from, for provenance and citation purposes.
data Source = Monograph | Website | PersonalCommunication

{- | A published or otherwise recorded description of a cultivar's appearance, distinct from
a 'Collection' (which observes a single tree's fruit) — a description is elicited testimony
about the cultivar in general, not a measurement of a particular specimen.
-}
data Description p = Description
  { cultivar :: UUID
  , author :: UUID
  , source :: Source
  , stated :: Appearance Described
  , published :: p Day
  , cites :: [UUID]
  , uuid :: UUID
  }
  deriving stock (Generic)
  deriving anyclass (FunctorB, TraversableB)

newtype UUIDMap a = UUIDMap {getUUIDMap :: Map UUID a}
  deriving newtype (Show, Eq, Functor, Foldable, FunctorWithIndex UUID, FoldableWithIndex UUID)
  deriving stock (Traversable)

instance TraversableWithIndex UUID UUIDMap where
  itraverse f (UUIDMap m) = UUIDMap <$> itraverse f m

insert :: (HasField "uuid" a UUID) => a -> UUIDMap a -> UUIDMap a
insert a (UUIDMap m) = UUIDMap $ Map.insert a.uuid a m

data Observations = Observations
  { collections :: UUIDMap (Collection Observed)
  , trees :: UUIDMap (Tree Observed)
  , judgements :: UUIDMap (Judgement Observed)
  , descriptions :: UUIDMap (Description Maybe)
  }

data Database = Database
  { people :: UUIDMap Person
  , cultivars :: UUIDMap Cultivar
  , observations :: Observations
  }
