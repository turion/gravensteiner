module Scale (test) where

-- base
import Data.Functor.Identity (Identity (..))
import Data.Maybe (fromJust, isJust)
import Prelude

-- hspec
import Test.Hspec

-- dimensional. Deliberately not the wholesale prelude import: it hides 'log', 'exp', '(-)' and
-- '(/)', and these tests mix dimensional's '/' in @h / d@ with ordinary 'Double' subtraction and
-- @log 10@. So only the unit values and '(*~)' come in unqualified, and '(/)' comes in qualified.
import Numeric.Units.Dimensional.Prelude (centi, gram, metre, milli, (*~))
import Numeric.Units.Dimensional.Prelude qualified as Dim ((/))

-- gravensteiner
import Gravensteiner.Model (Closed (..), ClosedInterval, GroundColour (..), Interval, getInterval, interval)
import Gravensteiner.Model.Scale

{- | Absolute-difference tolerance for every floating-point comparison in this module. None of
these clauses -- including the log-10 shift, which looks exact -- holds under '(==)': SI
conversions round, and composing 'log'/'exp' or 'logitInterval'/'logisticInterval' accumulates a
little more error on top. 1e-9 is generous against both sources, which are only ever a handful of
floating-point ULPs.
-}
tol :: Double
tol = 1e-9

approx :: Double -> Double -> Bool
approx expected actual = abs (actual - expected) < tol

{- | Unwraps a known-interior literal into an 'Interval', for building test fixtures below --
every literal passed here is safely inside (0, 1).
-}
mkInterval :: Double -> Interval
mkInterval = fromJust . interval

{- | The 'logClosed'\/'unLogClosed' round trip, checked at whichever constructor it is given:
'Minimal' and 'Maximal' round-trip exactly (no 'Double' payload to drift), and a 'Graded'
payload round-trips within 'tol'. The one predicate every round-trip test below drives, so the
check is stated once rather than once per constructor and again per 'GroundColour' field.
-}
roundTripsClosed :: ClosedInterval -> Expectation
roundTripsClosed Minimal = unLogClosed (logClosed Minimal) `shouldBe` (Minimal :: ClosedInterval)
roundTripsClosed Maximal = unLogClosed (logClosed Maximal) `shouldBe` (Maximal :: ClosedInterval)
roundTripsClosed (Graded iv) = case unLogClosed (logClosed (Graded iv)) of
  Graded iv' -> getInterval iv' `shouldSatisfy` approx (getInterval iv)
  other -> expectationFailure ("expected Graded, got " <> show other)

test :: Spec
test = describe "Gravensteiner.Model.Scale" $ do
  describe "unit invariance" $ do
    -- The canonical diameter from this module's own haddocks.
    let d = (58 :: Double) *~ milli metre
        h = (70 :: Double) *~ milli metre

    it "shifts the length coordinate by log 10, centimetre minus millimetre" $
      (logLength (centi metre) d - logLength (milli metre) d)
        `shouldSatisfy` approx (negate (log 10))

    it "leaves the shape coordinate invariant under the length reference unit" $ do
      let diffMilli = logLength (milli metre) h - logLength (milli metre) d
          diffCenti = logLength (centi metre) h - logLength (centi metre) d
          shapeVal = logShape (h Dim./ d)
      diffCenti `shouldSatisfy` approx diffMilli
      shapeVal `shouldSatisfy` approx diffMilli
      shapeVal `shouldSatisfy` approx diffCenti

  describe "default units" $ do
    -- These pin the reference unit itself, unlike the round trips below: a round trip still
    -- passes if 'logDiameter' and 'unLogDiameter' are both changed to the same wrong unit, because
    -- the inverse absorbs the change. Comparing against 'log' of the bare magnitude, computed
    -- independently of the transform's own unit choice, is what catches that drift.
    it "logDiameter reads its argument in millimetres" $
      logDiameter ((58 :: Double) *~ milli metre) `shouldSatisfy` approx (log 58)

    it "logWeight reads its argument in grams" $
      logWeight ((142 :: Double) *~ gram) `shouldSatisfy` approx (log 142)

  describe "round trips" $ do
    -- 'ClosedInterval' fields (overcolour, russet, and now ground colour's own 'green' and
    -- 'yellow') close both ends in the type itself, so 'logClosed'/'unLogClosed' are round-tripped
    -- below at all three constructors, 'Minimal' and 'Maximal' included, not just the interior.
    -- 'certainty' is the one remaining plain 'Interval' field with no absent constructor of its
    -- own; 'logitInterval'/'logisticInterval' below exercise the interior payload shared by that
    -- field and by every 'Graded' value.
    it "logit/logistic round-trips an interior Interval value" $
      mapM_
        ( \p ->
            getInterval (logisticInterval (logitInterval (mkInterval p)))
              `shouldSatisfy` approx p
        )
        [0.02, 0.5, 0.97]

    it "logClosed/unLogClosed round-trips Minimal" $
      roundTripsClosed Minimal

    it "logClosed/unLogClosed round-trips Maximal" $
      roundTripsClosed Maximal

    it "logClosed/unLogClosed round-trips an interior Graded value" $
      mapM_ (roundTripsClosed . Graded . mkInterval) [0.02, 0.5, 0.97]

    it "logit/logistic round-trips past both saturation thresholds, at both infinities, and at NaN" $
      -- The naive @1 / (1 + exp (-x))@ hits exactly 0.0 or 1.0 well before these magnitudes --
      -- around +-37, then again at +-infinity -- which is the bug 'logisticInterval' now guards
      -- against. 'NaN' takes the same dedicated branch, since it saturates neither comparison.
      -- Every one of these must still come back strictly interior, and its own logit
      -- must be finite: the two 'Done when' clauses this test exists to satisfy.
      mapM_
        ( \x ->
            let iv = logisticInterval x
                p = getInterval iv
             in do
                  p `shouldSatisfy` \v -> v > 0 && v < 1
                  logitInterval iv `shouldSatisfy` \l -> not (isNaN l) && not (isInfinite l)
        )
        [37, 40, 100, 745, 800, 1000, 1 / 0, -37, -40, -100, -745, -800, -1000, -(1 / 0), 0 / 0]

    -- Ground colour's own two fields, 'green' and 'yellow' (each a 'ClosedInterval'), go through
    -- the same 'logClosed'/'unLogClosed' pair as 'overcolour' and 'russet' -- there is no
    -- field-specific transform, by design. These assertions build an actual 'GroundColour
    -- Identity' and go through its real record accessors, at all three constructors each, rather
    -- than relying on the generic 'ClosedInterval' tests above to stand in for them.
    let mkGroundColour :: ClosedInterval -> ClosedInterval -> GroundColour Identity
        mkGroundColour g y = GroundColour {green = Identity g, yellow = Identity y}

    describe "GroundColour's green and yellow" $ do
      it "round-trips green at Minimal" $
        roundTripsClosed (runIdentity (green (mkGroundColour Minimal Minimal)))

      it "round-trips green at Maximal" $
        roundTripsClosed (runIdentity (green (mkGroundColour Maximal Minimal)))

      it "round-trips green's interior Graded value" $
        mapM_
          (\p -> roundTripsClosed (runIdentity (green (mkGroundColour (Graded (mkInterval p)) Minimal))))
          [0.02, 0.5, 0.97]

      it "round-trips yellow at Minimal" $
        roundTripsClosed (runIdentity (yellow (mkGroundColour Minimal Minimal)))

      it "round-trips yellow at Maximal" $
        roundTripsClosed (runIdentity (yellow (mkGroundColour Minimal Maximal)))

      it "round-trips yellow's interior Graded value" $
        mapM_
          (\p -> roundTripsClosed (runIdentity (yellow (mkGroundColour Minimal (Graded (mkInterval p))))))
          [0.02, 0.5, 0.97]

    it "log/exp round-trips a length" $
      mapM_
        (\x -> logLength (milli metre) (unLogLength (milli metre) x) `shouldSatisfy` approx x)
        [-3, 0, 4]

    it "log/exp round-trips a mass" $
      mapM_
        (\x -> logMass gram (unLogMass gram x) `shouldSatisfy` approx x)
        [-2, 0, 5]

    it "log/exp round-trips a length under the millimetre default" $
      mapM_
        (\x -> logDiameter (unLogDiameter x) `shouldSatisfy` approx x)
        [-3, 0, 4]

    it "log/exp round-trips a mass under the gram default" $
      mapM_
        (\x -> logWeight (unLogWeight x) `shouldSatisfy` approx x)
        [-2, 0, 5]

    it "log/exp round-trips a height/diameter ratio" $
      mapM_
        (\x -> logShape (unLogShape x) `shouldSatisfy` approx x)
        [-1, 0, 2]

  describe "absent coordinates" $ do
    it "Minimal has no coordinate to be non-finite" $
      logClosed (Minimal :: ClosedInterval) `shouldBe` Minimal

    it "Maximal has no coordinate to be non-finite" $
      logClosed (Maximal :: ClosedInterval) `shouldBe` Maximal

    it "an interior Graded extent yields a finite coordinate" $
      case logClosed (Graded (mkInterval 0.3)) of
        Graded v -> v `shouldSatisfy` (not . isInfinite)
        other -> expectationFailure ("expected Graded, got " <> show other)

  describe "interval" $ do
    it "rejects the lower endpoint" $
      interval 0 `shouldBe` Nothing

    it "rejects the upper endpoint" $
      interval 1 `shouldBe` Nothing

    it "rejects a value below 0" $
      interval (-0.1) `shouldBe` Nothing

    it "rejects a value above 1" $
      interval 1.1 `shouldBe` Nothing

    it "rejects NaN" $
      interval (0 / 0) `shouldBe` Nothing

    it "rejects positive infinity" $
      interval (1 / 0) `shouldBe` Nothing

    it "rejects negative infinity" $
      interval (-1 / 0) `shouldBe` Nothing

    it "accepts an interior value" $
      interval 0.5 `shouldSatisfy` isJust

    it "accepts the suite's existing interior literals" $
      mapM_ (\p -> interval p `shouldSatisfy` isJust) [0.02, 0.3, 0.5, 0.97]
