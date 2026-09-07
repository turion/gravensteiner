{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE NoImplicitPrelude #-}

{- | Some types are tagged with a higher kinded datatype phase that can be used to mark parts of the data as being "not observed" via 'Maybe' or 'Observed'.
Sampling data on the other hand will always produce data, so can use 'Identity' as the phase.
-}
module Gravensteiner.Model (
  module Gravensteiner.Model,
  Interval,
  getInterval,
  interval,
) where

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

-- gravensteiner
import Gravensteiner.Model.Interval (Interval, getInterval, interval)

-- | Recorded in serialisation to allow for future migrations
version :: Int
version = 1

data Person = Person
  { name :: Text
  , email :: Maybe Text
  , phone :: Maybe Text
  , uuid :: UUID
  }

{- | A @[0,1]@ reading recorded at either closed end without ever forcing 'logit' to an infinity:
an observer cannot distinguish a coverage of 0 from 0.000001, so "none of this at all" and "all of
it" are states a pomologist really does record, not points a continuous judgement happens to land
on. 'Minimal' and 'Maximal' are the two structural endpoints; 'Graded' carries the judged position
strictly between them, via 'Interval'.

A logit-normal assigns zero density to the endpoints -- @logit 0 = -Infinity@ is not a numerical
inconvenience a sampler routes around -- so giving them positive probability needs a mixture: a
discrete component at the boundary plus a continuous one inside. That mixture is what the three
constructors are: the presence indicator (which endpoint, if any) is directly observed and
contributes a Bernoulli likelihood with no latent variable, and 'Graded's payload is a second,
nested Beta-Bernoulli layer inside it -- two such layers in stick-breaking order are a generalized
Dirichlet, which contains the Dirichlet as a special case.
-}
data Closed a = Minimal | Graded a | Maximal
  deriving stock (Show, Eq, Functor)

{- | A closed-interval reading: 'Minimal', an interior 'Interval' via 'Graded', or 'Maximal'. Used
at every field recording a coverage or extent that can genuinely reach either end -- see 'Closed'.
-}
type ClosedInterval = Closed Interval

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

{- | Ground colour is __two independently phased axes, not one__: 'green' is the chlorophyll
reading and 'yellow' the carotenoid one. A single green-to-orange axis assumes the two pigments move
in lockstep, which they do not -- a cultivar that goes deep green to deep gold and a paler one that
goes green to near-cream would land at the same mid-axis point on a conflated single axis, and be
indistinguishable. The phase distributes into this record rather than sitting once on 'Colouration',
exactly as 'Colouration' itself distributes into 'Appearance' (see 'colouration') -- each field keeps
its own @p@, so a source can state green without mentioning yellow. Fully green is
@green = 'Maximal', yellow = 'Minimal'@: each endpoint now means one simple thing, no chlorophyll at
all or no carotenoid at all, rather than two ends of a conflated axis. A base skin entirely hidden
under blush (UPOV's ground colour __"not visible"__) is /not observed/ for either field, exactly as
before -- an absent phase value, not a position on either axis.

ECPGR Table 16's six ordered ground-colour states, quoted below, describe exactly the conflated
single axis this record replaces -- a __one-dimensional ordinal descriptor__, not two independent
readings -- so they no longer anchor a live reading of either field below. Re-anchoring them onto two
axes is domain work nobody has done (see @research\/descriptor-standards.md@, the arc's research
directory); neither 'green' nor 'yellow' states a calibration anchor, and none should be invented.
(This is the table's canonical home. @docs\/collection-form.md@ quotes the same states for the
observer, in plain form, since a Haddock comment cannot render a markdown table.) No axis-band
number or project anchor is reproduced here: ECPGR numbers these same states the other way round
(Yellow is 1, Green is 5), and giving them a second, reversed number alongside ECPGR's own invited
exactly that mix-up.

+-------------------+---------------------+
| ECPGR state       | Reference           |
|                   | cultivar            |
+===================+=====================+
| Green             | Granny Smith        |
+-------------------+---------------------+
| Whitish green     |                     |
+-------------------+---------------------+
| Green yellow      | Cox's Orange Pippin |
+-------------------+---------------------+
| Whitish yellow    |                     |
+-------------------+---------------------+
| Yellow            | Golden Delicious    |
+-------------------+---------------------+
| (Yellow) - Orange |                     |
+-------------------+---------------------+

The state names and cultivars above are ECPGR Table 16's own one-dimensional states; they no longer
describe a value stored anywhere in this model.
-}
data GroundColour p = GroundColour
  { green :: p ClosedInterval
  {- ^ The base skin's chlorophyll reading -- the __base skin__ being the skin that is neither
  russeted nor blushed (see 'russet' and 'overcolour'): the position between no chlorophyll left at
  all and as green as chlorophyll gets, an intensity rather than an area fraction. 'Minimal' is no
  chlorophyll left at all; 'Maximal' is the fully green extreme. No calibration anchor is
  established for this axis: ECPGR describes ground colour as a single ordinal state (see
  'GroundColour'\'s table above), not as a chlorophyll extent judged on its own, so there is nothing
  sourced to anchor this field against yet.
  -}
  , yellow :: p ClosedInterval
  {- ^ The base skin's carotenoid reading: the position between no carotenoid revealed at all and as
  yellow as carotenoid gets, an intensity rather than an area fraction (see 'green' for the same
  distinction). 'Minimal' is no carotenoid revealed at all; 'Maximal' is the fully yellow extreme.
  This axis does not currently separate yellow from orange: what ECPGR calls "(Yellow) - Orange" has
  no representation of its own here, so an orange base skin also reads 'Maximal' -- a limitation of
  the axis as it stands, not a claim that the two are the same colour.

  __Always recorded, even when 'green' reads strongly green.__ Chlorophyll masks carotenoid, so a
  yellow reading taken under high green is arguably a ripeness prediction rather than an observation;
  recording it as absent under high green instead was considered and rejected, because whether the
  masking is a real problem is something to settle empirically once there is data, not by
  construction now. No calibration anchor is established for this axis either, for the same reason as
  'green'.
  -}
  }
  deriving stock (Generic)
  deriving anyclass (FunctorB, TraversableB, ApplicativeB, ConstraintsB)

{- | The three colour-related fields of 'Appearance', phase-parameterised /per field/ rather than as
a whole: a source that states ground colour without mentioning blush is recordable as exactly that,
which a single @p Colouration@ could not express. Questions producing these numbers are defined in
@docs\/collection-form.md@.
-}
data Colouration p = Colouration
  { groundColour :: GroundColour p
  -- ^ Two independently phased axes, chlorophyll and carotenoid -- see 'GroundColour'.
  , overcolour :: p ClosedInterval
  {- ^ Extent as a fraction of __non-russeted__ skin, not of the whole fruit: the whole-apple
  reading makes visible red approximately @blush * (1 - russet)@, bilinear in two latents, which
  breaks conjugacy. 'Minimal' is ECPGR's over colour coverage scale's "Absent, 0 %", its own named
  state with three reference cultivars (Granny Smith, Treboux, Kaja) rather than a limiting case of
  a coverage that happens to be zero. 'Maximal' is the symmetric fully-overcoloured endpoint;
  neither ECPGR nor UPOV names a 100 % state with its own reference cultivar, so none is given here
  either.
  -}
  , overcolourPattern :: p OvercolourPattern
  {- ^ Deliberately not nested inside 'overcolour''s extent: pairing the extent with the pattern
  would stop a source stating one without the other, which is what the per-field phase parameter
  is for.
  -}
  }
  deriving stock (Generic)
  deriving anyclass (FunctorB, TraversableB, ApplicativeB, ConstraintsB)

-- | Measurable large-scale shape of a fruit.
data Shape p = Shape
  { height :: p (Length Rational)
  {- ^ Taken at the tallest point of the flesh, not the polar axis through the stalk cavity and calyx basin, per UPOV TG/14
  characteristic 23. Units come from "Numeric.Units.Dimensional.SIUnits" via the re-exporting prelude, e.g. @58 *~ milli metre@.
  The reference unit for the log scale this feeds is the __millimetre__. An exact 'Rational' reading,
  like every other value the observer records -- see "Gravensteiner.Model.Interval"'s haddock for why.
  -}
  , diameter :: p (Length Rational)
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
heightDiameterRatio :: (Functor p, Applicative p) => Shape p -> p (Dimensionless Rational)
heightDiameterRatio s = (/) <$> s.height <*> s.diameter

-- | Everything that can be directly observed about a fruit
data Appearance p = Appearance
  { colouration :: Colouration p
  , russet :: p ClosedInterval
  {- ^ Its own field rather than nested in 'Colouration': russet is a texture, not a colouration.
  How much of the fruit's surface is russeted, i.e. covered in a dull brown rough finish (UPOV
  *Ad. 35*). 'Minimal' is ECPGR Table 20's "Absent, 0 %" (Lobo), its own named state, while UPOV
  folds absent into "absent or small" and so does not distinguish it. 'Maximal' is the symmetric
  fully-russeted endpoint; neither standard names a 100 % state with its own reference cultivar, so
  none is given here either. 'Graded's extent, when present, is overall coverage -- ECPGR's
  Priority-1 aggregate over cheeks, eye basin and stalk cavity, not UPOV's three per-zone
  characteristics.
  -}
  , shape :: Shape p
  , weight :: p (Mass Rational)
  {- ^ The whole fruit, weighed on a kitchen scale. Example: @142 *~ gram@. The reference unit for
  the log scale this feeds is the __gram__. An exact 'Rational' reading, like every other value the
  observer records.
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

{- | Whether a 'Description' stated a value for a field at all -- kept distinct from whether a
stated value itself asserts presence or absence. A monograph silent about a feature has not
claimed the feature is absent: recording that silence as a stated 'Minimal' would feed a positive
claim of absence into the model's presence layer, which treats it as an observed Bernoulli outcome
the source never gave. 'NotDescribed' is silence, the field was never brought up at all;
'DescribedAs' is a value the source did state, including a stated absence -- only when the source
explicitly says the fruit carries none of the feature does 'Minimal' belong inside it. The
collection form's "Reading from a published description" section gives the observer the same rule
in their own words: record silence as "not mentioned", kept separate from "none".
-}
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
