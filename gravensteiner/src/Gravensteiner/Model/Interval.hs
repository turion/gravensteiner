{- | 'Interval', kept in its own module so its exported interface can be tight: everywhere else in
"Gravensteiner.Model" the module has no export list at all, and hand-writing one for the whole
module just to hide this one constructor would be disproportionate. 'Gravensteiner.Model'
re-exports 'Interval', 'getInterval' and 'interval' from here, but not the raw data constructor --
so 'interval' is the only way to build one outside this module and "Gravensteiner.Model.Scale"
(which needs the internal-only route below).
-}
module Gravensteiner.Model.Interval (
  Interval,
  getInterval,
  interval,
  unsafeInterval,
) where

{- | A number known to lie strictly between 0 and 1, e.g. a probability or a coverage fraction --
backed by 'Rational' rather than 'Double', because every value the observer records is an exact
reading, never a floating-point approximation of one. The only publicly reachable way to construct
one is 'interval'.

/No/ 'Floating' instance is derived, and none can be: 'Rational' has none, @logit@ of a rational is
transcendental, and no exact representation of it exists even in principle. The logit\/logistic
coordinate transform in "Gravensteiner.Model.Scale" is where the unavoidable 'Double' step happens.
-}
newtype Interval = Interval {getInterval :: Rational}
  deriving stock (Show, Eq, Ord)
  deriving newtype (Num, Fractional)

{- | The smart constructor: 'Nothing' for anything that is not strictly between 0 and 1. There is
no @isNaN@\/@isInfinite@ guard here any more -- not because the check became unneeded, but because
it became /ill-typed/: 'Rational' has no @NaN@ and no infinity to admit in the first place, so the
old guard would need a 'RealFloat' constraint this type can no longer satisfy. The strict @0 < x <
1@ test is the whole check now. Every 'Interval' eventually feeds @logit@ (see
"Gravensteiner.Model.Scale"), which is undefined at both endpoints, so this rejects them rather
than silently producing an infinite coordinate downstream.
-}
interval :: Rational -> Maybe Interval
interval x
  | x <= 0 || x >= 1 = Nothing
  | otherwise = Just (Interval x)

{- | Unchecked construction, for callers that can prove interiority some other way instead of
paying for the check -- currently only 'Gravensteiner.Model.Scale.logisticInterval', and only for
fixed epsilon literals it can prove interior by inspection, /not/ for the logistic function's raw
output: in 'Double', @1 \/ (1 + exp (-x))@ saturates to exactly @0.0@ or @1.0@ for large enough
@|x|@, so "the logistic function's range is always (0, 1) for finite input" is false in floating
point and is not a justification this constructor can rely on -- even once the saturated 'Double'
is converted to an exact 'Rational', it is exactly @0@ or @1@, not merely close. Exported from this
module only: "Gravensteiner.Model" does not re-export it, so every other consumer must go through
'interval'.
-}
unsafeInterval :: Rational -> Interval
unsafeInterval = Interval
