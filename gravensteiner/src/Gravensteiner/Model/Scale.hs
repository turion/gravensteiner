{-# LANGUAGE NoImplicitPrelude #-}

{- | Transforms between recorded, real-world measurements and the network design's unconstrained
continuous coordinates -- the vector documented in
@research\/appearance-coordinates.md@ (the arc's shared research directory, not shipped with this
package): logit ground colour, logit overcolour extent, logit russet extent, log weight, log
diameter and log height\/diameter ratio. Every constrained quantity in the model gets to this scale
by log or logit, per @todo\/model-v1-bayesian-network.md@'s rule that features live on a scale where
they are normal.

The length and mass transforms take their reference unit as an /argument/ rather than baking one
into the function body. With "Numeric.Units.Dimensional", @58 *~ milli metre@ and
@5.8 *~ centi metre@ represent the same physical quantity but are not bit-identical -- the SI
conversion rounds -- so a transform that hard-codes @\/~ milli metre@ would offer no way to express
"the same measurement on a different reference scale". That expressiveness is exactly what todo 4's
unit-invariance test needs: it re-runs a transform under a different unit and checks the invariant
coordinate does not move. 'logDiameter' and 'logWeight' are the millimetre and gram defaults that
the rest of the model actually uses.

Every transform here has an inverse, also in this module. None of the inverses has a caller yet in
this arc beyond todo 4's round-trip tests -- their eventual customer is reporting a fitted marginal
back to a person in millimetres and grams, which is milestone-3 work (@todo\/README.md@'s next
planning session, items 6 and 7, both blocked on a seed corpus this arc does not provide), not dead
code.

Deliberately narrow: arithmetic on recorded values only. No inference, no "delayed-sampling"
import, no distributions -- those belong to the milestone-3 chain this module feeds, not to a
down payment on it here.
-}
module Gravensteiner.Model.Scale where

-- base
import Prelude qualified as P

-- dimensional
import Numeric.Units.Dimensional.Prelude

-- gravensteiner
import Gravensteiner.Model (Interval (..), Overcolour (..), Russet (..))

{- | Ground colour to the logit scale. 'Interval' is an unguarded @newtype@ over 'Double' with no
smart constructor, so this is partial at the boundary in the same way 'Prelude.log' is: the house
rule that no recorded answer is ever exactly 0 or 1 (see the collection form) is what keeps this
finite in practice, not anything this function checks.
-}
logitInterval :: Interval -> Double
logitInterval (Interval p) = P.log (p P./ (1 P.- p))

-- | Inverse of 'logitInterval'.
logisticInterval :: Double -> Interval
logisticInterval x = Interval (1 P./ (1 P.+ P.exp (P.negate x)))

{- | Overcolour extent to the logit scale, 'Nothing' when the fruit shows no overcolour at all.
The optionality lives in the type -- "the coordinate is simply absent when the feature is zero" is
then a fact the compiler knows, not a rule stated in a comment.
-}
logOvercolour :: Overcolour -> Maybe Double
logOvercolour NoOvercolour = Nothing
logOvercolour (Overcoloured extent) = Just (logitInterval extent)

-- | Inverse of 'logOvercolour'.
unLogOvercolour :: Maybe Double -> Overcolour
unLogOvercolour Nothing = NoOvercolour
unLogOvercolour (Just x) = Overcoloured (logisticInterval x)

{- | Russet extent to the logit scale, 'Nothing' when the fruit shows no russet at all. Same shape
as 'logOvercolour', for the same reason: russet's presence is observed directly and contributes no
latent variable, so the logit-normal coordinate is simply absent rather than a coordinate pinned at
@logit 0 = -Infinity@.
-}
logRusset :: Russet -> Maybe Double
logRusset NotRusseted = Nothing
logRusset (Russeted extent) = Just (logitInterval extent)

-- | Inverse of 'logRusset'.
unLogRusset :: Maybe Double -> Russet
unLogRusset Nothing = NotRusseted
unLogRusset (Just x) = Russeted (logisticInterval x)

{- | A length to the log scale, under a caller-supplied reference unit. Kept polymorphic in the
unit rather than fixed to 'logDiameter'\'s millimetre so that the same measurement, read off under a
different reference scale, still has a way to say so -- see the module haddock.
-}
logLength :: Unit m DLength Double -> Length Double -> Double
logLength u l = P.log (l /~ u)

-- | Inverse of 'logLength', under the same reference unit.
unLogLength :: Unit m DLength Double -> Double -> Length Double
unLogLength u x = P.exp x *~ u

-- | 'logLength' under the project's reference unit for lengths, the millimetre.
logDiameter :: Length Double -> Double
logDiameter = logLength (milli metre)

-- | Inverse of 'logDiameter'.
unLogDiameter :: Double -> Length Double
unLogDiameter = unLogLength (milli metre)

{- | A mass to the log scale, under a caller-supplied reference unit. Same reasoning as
'logLength'.
-}
logMass :: Unit m DMass Double -> Mass Double -> Double
logMass u mass = P.log (mass /~ u)

-- | Inverse of 'logMass', under the same reference unit.
unLogMass :: Unit m DMass Double -> Double -> Mass Double
unLogMass u x = P.exp x *~ u

-- | 'logMass' under the project's reference unit for weight, the gram.
logWeight :: Mass Double -> Double
logWeight = logMass gram

-- | Inverse of 'logWeight'.
unLogWeight :: Double -> Mass Double
unLogWeight = unLogMass gram

{- | The log of the height\/diameter ratio (see 'Gravensteiner.Model.heightDiameterRatio'), to the
unconstrained scale. Takes the ratio rather than the two lengths separately so that it has an
inverse: a two-lengths-to-one-number map has none, and both this module and todo 4 require every
transform to round-trip. No reference unit enters here, because whichever unit the two lengths were
read off in cancels between their two logs -- this coordinate is the one immune to the length-unit
choice that shifts 'logLength'.
-}
logShape :: Dimensionless Double -> Double
logShape ratio = P.log (ratio /~ one)

-- | Inverse of 'logShape'. Recovers the height\/diameter ratio, not the height-diameter pair.
unLogShape :: Double -> Dimensionless Double
unLogShape x = P.exp x *~ one
