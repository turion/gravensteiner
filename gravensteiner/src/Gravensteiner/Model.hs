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

{- | Whether a fruit shows any over colour (blush/flush) at all, mirroring 'Russet': the extent is a
fraction of __non-russeted__ skin (see 'overcolour' on 'Colouration'), and ECPGR's over colour
coverage scale makes "Absent, 0 %" its own state with three reference cultivars (Granny Smith,
Treboux, Kaja) rather than a limiting case of a coverage that happens to be zero. Kept as a
constructor rather than a zero for the same reason as 'Russet': @logit 0@ is @-Infinity@.
-}
data Overcolour = NoOvercolour | Overcoloured Interval
  deriving stock (Show, Eq)

{- | The union of UPOV char. 33 and ECPGR Table 19's over-colour pattern states (eight in total,
after merging the two standards' overlapping vocabulary). Deliberately a plain enum: a simplex over
these states would need Dirichlet-categorical, which is milestone 6, and 'version' is what carries a
later migration to one.
-}
data OvercolourPattern
  = {- | UPOV and ECPGR both. Reference cultivars: Richard Delicious (ECPGR); Bay 3484, Red
    Jonaprince, Telamon (UPOV).
    -}
    OnlySolidFlush
  | {- | UPOV and ECPGR both. Reference cultivars: __Gravensteiner__ (ECPGR); Charlotte, Cripps
    Pink (UPOV, among others).
    -}
    SolidFlushWithStripes
  | -- | UPOV and ECPGR both. Reference cultivar: Dülmener Rosenapfel.
    OnlyStripes
  | -- | UPOV only: mottling over a stated flush. Reference cultivars: Dalinbel, Scifresh.
    FlushedAndMottled
  | -- | UPOV only. Reference cultivars: Elstar, Pinova, Topaz (among others).
    FlushedStripedAndMottled
  | -- | UPOV only. Reference cultivar: Karneval.
    Marbled
  | {- | ECPGR only: mottling with no stated flush, distinct from 'FlushedAndMottled'. No reference
    cultivar given.
    -}
    Mottled
  | -- | ECPGR only. No reference cultivar given.
    WashedOut
  deriving stock (Show, Eq)

{- | The three colour-related fields of 'Appearance', phase-parameterised /per field/ rather than as
a whole: a source that states ground colour without mentioning blush is recordable as exactly that,
which a single @p Colouration@ could not express. Questions producing these numbers are defined in
@docs\/collection-form.md@.
-}
data Colouration p = Colouration
  { groundColour :: p Interval
  {- ^ 0 = green to 1 = yellow, read off the __base skin__: the skin that is neither russeted nor
  blushed (see @todo\/russet-is-not-a-colour.md@). __Never exactly 0 or 1__: unlike 'overcolour' and
  'russet', ground colour is a /position/ rather than a coverage, so it has no absent constructor to
  protect it, 'Interval' is an unguarded @newtype@ over 'Double', and @logit 0@\/@logit 1@ are both
  infinite. Record against six equal bands at their midpoints:

  +------+--------------------+---------+-----------------------+
  | Axis | ECPGR state        | Records | Anchor                |
  | band |                    | as      |                        |
  +======+====================+=========+========================+
  | 1    | Green              | 0.08    | Granny Smith           |
  +------+--------------------+---------+-----------------------+
  | 2    | Whitish green      | 0.25    |                        |
  +------+--------------------+---------+-----------------------+
  | 3    | Green yellow       | 0.42    | Cox's Orange Pippin    |
  +------+--------------------+---------+-----------------------+
  | 4    | Whitish yellow     | 0.58    |                        |
  +------+--------------------+---------+-----------------------+
  | 5    | Yellow             | 0.75    | Golden Delicious       |
  +------+--------------------+---------+-----------------------+
  | 6    | (Yellow) - Orange  | 0.92    |                        |
  +------+--------------------+---------+-----------------------+

  So Granny Smith reads 0.08 and Golden Delicious 0.75, /not/ 0 and 1. The state names and
  cultivars above are __ECPGR Table 16's__; the [0,1] values are __this project's own convention__
  of six equal bands recorded at their midpoints, and ECPGR publishes no numbers for them. The axis
  banding runs green-to-yellow, the /reverse/ of ECPGR's own state numbering (Table 16 numbers
  Yellow 1 and Green 5) — an ECPGR state number must never be cited against an axis band.

  Two boundary cases, both settled by the maintainer: a ground colour ECPGR calls
  "(Yellow) - Orange" is __band 6, 0.92 — past yellow on the same axis, not off it__, which keeps
  the axis monotone in ripeness since it tracks chlorophyll degrading to reveal carotenoids. A
  fruit whose ground colour UPOV would call __"not visible"__ (fully blushed) is /not observed/, not
  a value on the axis.
  -}
  , overcolour :: p Overcolour
  {- ^ Extent as a fraction of __non-russeted__ skin, not of the whole fruit: the whole-apple
  reading makes visible red approximately @blush * (1 - russet)@, bilinear in two latents, which
  breaks conjugacy.
  -}
  , overcolourPattern :: p OvercolourPattern
  {- ^ Deliberately not nested inside 'Overcoloured': pairing the extent with the pattern would stop
  a source stating one without the other, which is what the per-field phase parameter is for.
  -}
  }
  deriving stock (Generic)
  deriving anyclass (FunctorB, TraversableB, ApplicativeB, ConstraintsB)

{- | How much of the fruit's surface is russeted, i.e. covered in a dull brown rough finish (UPOV
*Ad. 35*). ECPGR Table 20 makes "Absent, 0 %" its own state (Lobo), while UPOV folds absent into
"absent or small" and so does not distinguish it; kept as a constructor for the same reason as
'Overcolour', to keep a zero away from 'logit'. The extent, when present, is overall coverage --
ECPGR's Priority-1 aggregate over cheeks, eye basin and stalk cavity, not UPOV's three per-zone
characteristics.
-}
data Russet = NotRusseted | Russeted Interval
  deriving stock (Show, Eq)

-- | Measurable large-scale shape of a fruit.
data Shape p = Shape
  { height :: p (Length Double)
  {- ^ Taken at the tallest point of the flesh, not the polar axis through the stalk cavity and calyx basin, per UPOV TG/14
  characteristic 23. Units come from "Numeric.Units.Dimensional.SIUnits" via the re-exporting prelude, e.g. @58 *~ milli metre@.
  The reference unit for the log scale this feeds is the __millimetre__.
  -}
  , diameter :: p (Length Double)
  {- ^ Taken at the widest point, the fruit's equator (UPOV TG/14 characteristic 24); "maximum" here
  names the caliper site, not a maximum over repeated measurements. E.g. @71 *~ milli metre@. The
  reference unit for the log scale this feeds is the __millimetre__.
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
  { colouration :: Colouration p
  , russet :: p Russet
  -- ^ Its own field rather than nested in 'Colouration': russet is a texture, not a colouration.
  , shape :: Shape p
  , weight :: p (Mass Double)
  {- ^ The whole fruit, weighed on a kitchen scale. Example: @142 *~ gram@. The reference unit for
  the log scale this feeds is the __gram__.
  -}
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
