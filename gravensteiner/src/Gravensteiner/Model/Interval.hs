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

{- | A number known to lie strictly between 0 and 1, e.g. a probability or a coverage fraction.
The only publicly reachable way to construct one is 'interval'.
-}
newtype Interval = Interval {getInterval :: Double}
  deriving stock (Show, Eq, Ord)
  deriving newtype (Num, Fractional, Floating)

{- | The smart constructor: 'Nothing' for anything that is not strictly between 0 and 1, including
@NaN@ and both infinities. Every 'Interval' eventually feeds @logit@ (see
"Gravensteiner.Model.Scale"), which is undefined at both endpoints, so this rejects them rather
than silently producing an infinite coordinate downstream.
-}
interval :: Double -> Maybe Interval
interval x
  | isNaN x || isInfinite x = Nothing
  | x <= 0 || x >= 1 = Nothing
  | otherwise = Just (Interval x)

{- | Unchecked construction, for callers that can prove interiority some other way instead of
paying for the check -- currently only 'Gravensteiner.Model.Scale.logisticInterval', whose
logistic function's range is always (0, 1) for finite input. Exported from this module only:
"Gravensteiner.Model" does not re-export it, so every other consumer must go through 'interval'.
-}
unsafeInterval :: Double -> Interval
unsafeInterval = Interval
