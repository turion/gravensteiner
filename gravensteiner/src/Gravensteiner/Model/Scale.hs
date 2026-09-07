{-# LANGUAGE NoImplicitPrelude #-}

{- | Transforms between recorded, real-world measurements and the network design's unconstrained
continuous coordinates -- the vector documented in
@research\/appearance-coordinates.md@ (the arc's shared research directory, not shipped with this
package): logit ground colour's green and yellow axes, logit overcolour extent, logit russet
extent, log weight and log diameter. Every constrained quantity in the
model gets to this scale by log or logit, per @todo\/model-v1-bayesian-network.md@'s rule that
features live on a scale where they are normal. The shape coordinate is the exception: it is the
bare height\/diameter ratio, 'Gravensteiner.Model.heightDiameterRatio', already unit-invariant by
construction and not put through a log or logit here.

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
import Data.Ratio ((%))
import Prelude qualified as P

-- dimensional
import Numeric.Units.Dimensional.Prelude

-- gravensteiner
import Gravensteiner.Model (Closed, ClosedInterval)
import Gravensteiner.Model.Interval (Interval, getInterval, interval, unsafeInterval)

{- | An open-interval @(0,1)@ reading to the logit scale -- the interior payload of a 'Graded'
value, and of plain-'Interval' fields such as 'Gravensteiner.Model.certainty'. 'Interval' guards
the (0, 1) rule itself -- every 'Interval' in existence has gone through either 'interval', which
rejects both endpoints (no non-finite value is even representable in 'Rational', so there is
nothing else left to reject), or 'logisticInterval'\'s own interior check below -- so this can no
longer produce @+-Infinity@, full stop, not just "for a validly constructed argument". The
'Interval' itself is exact; only this conversion to the logit coordinate has a 'Double' step, via
'fromRational'.
-}
logitInterval :: Interval -> Double
logitInterval p = P.log (x P./ (1 P.- x))
  where
    x = fromRational (getInterval p) :: Double

{- | Inverse of 'logitInterval'. Total, as it must be: every fitted marginal is a 'Double' that
has to become a reading. The naive @1 \/ (1 + exp (-x))@ saturates to exactly @0.0@ or @1.0@ once
@x@ passes roughly \(\pm 37\) (verified: 'Double' has no room between @0.9999999999999998@ and
@1.0@), which 'interval' would reject -- so this checks the naive result first and, only for the
handful of magnitudes where it saturates, falls back to a fixed epsilon on the appropriate side
rather than the unreachable exact endpoint. That keeps the interior round trip untouched: every
input that does not saturate takes the checked branch unchanged, converted with 'toRational' into
an exact reading. A @NaN@ input -- which no caller should ever produce, since it cannot come from a
finite fitted marginal -- falls back to the midpoint rather than propagating, purely to keep this
total; the midpoint it produces is an exact @1 % 2@, indistinguishable from an ordinary reading,
which is the sense in which a @NaN@ coordinate gets laundered here.
-}
logisticInterval :: Double -> Interval
logisticInterval x
  | isNaN x = unsafeInterval 0.5
  | otherwise = case interval (toRational y) of
      Just iv -> iv
      Nothing -> unsafeInterval (if x <= 0 then epsilon else 1 P.- epsilon)
  where
    y = 1 P./ (1 P.+ P.exp (P.negate x))
    -- Small enough to be indistinguishable from the true saturated limit at any magnitude the
    -- suite exercises, and large enough that its 'logitInterval' stays comfortably finite rather
    -- than merely non-infinite. An exact 'Rational' literal, not a decimal approximation standing
    -- in for one.
    epsilon :: Rational
    epsilon = 1 % (10 P.^ (15 :: Int))

{- | A 'ClosedInterval' reading to the logit scale: 'Minimal' and 'Maximal' carry no payload and so
stay themselves, and 'Graded's interior 'Interval' becomes a 'Double' via 'logitInterval'. The
presence indicator (which of the three this is) is directly observed and contributes a Bernoulli
likelihood with no latent variable, so the logit coordinate is simply /absent/ at an endpoint --
'Minimal'/'Maximal' carry no @Double@ to be missing -- rather than pinned at an infinity.
-}
logClosed :: ClosedInterval -> Closed Double
logClosed = fmap logitInterval

-- | Inverse of 'logClosed'.
unLogClosed :: Closed Double -> ClosedInterval
unLogClosed = fmap logisticInterval

{- | A length to the log scale, under a caller-supplied reference unit. Kept polymorphic in the
unit rather than fixed to 'logDiameter'\'s millimetre so that the same measurement, read off under a
different reference scale, still has a way to say so -- see the module haddock. The measurement
itself is an exact 'Rational' reading (see "Gravensteiner.Model.Interval"'s haddock for why); only
the log coordinate this produces is 'Double'.
-}
logLength :: Unit m DLength Rational -> Length Rational -> Double
logLength u l = P.log (fromRational (l /~ u))

{- | Inverse of 'logLength', under the same reference unit. Converts the naive 'Double' result back
to an exact reading with 'toRational'.
-}
unLogLength :: Unit m DLength Rational -> Double -> Length Rational
unLogLength u x = toRational (P.exp x) *~ u

-- | 'logLength' under the project's reference unit for lengths, the millimetre.
logDiameter :: Length Rational -> Double
logDiameter = logLength (milli metre)

-- | Inverse of 'logDiameter'.
unLogDiameter :: Double -> Length Rational
unLogDiameter = unLogLength (milli metre)

{- | A mass to the log scale, under a caller-supplied reference unit. Same reasoning as
'logLength'.
-}
logMass :: Unit m DMass Rational -> Mass Rational -> Double
logMass u mass = P.log (fromRational (mass /~ u))

-- | Inverse of 'logMass', under the same reference unit.
unLogMass :: Unit m DMass Rational -> Double -> Mass Rational
unLogMass u x = toRational (P.exp x) *~ u

-- | 'logMass' under the project's reference unit for weight, the gram.
logWeight :: Mass Rational -> Double
logWeight = logMass gram

-- | Inverse of 'logWeight'.
unLogWeight :: Double -> Mass Rational
unLogWeight = unLogMass gram
