module Scale (test) where

-- base
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
import Gravensteiner.Model (Closed (..), ClosedInterval, Interval, getInterval, interval)
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
    -- Ground colour has no absent constructor at all and is exposed at both ends; what keeps it
    -- away from 0 and 1 is the collection form's own rule, not the type. So this suite stays
    -- strictly inside (0, 1) for ground colour specifically -- a known gap, not evidence there is
    -- none. 'ClosedInterval' fields (overcolour, russet) close both ends in the type itself, so
    -- 'logClosed'/'unLogClosed' are round-tripped below at all three constructors, 'Minimal' and
    -- 'Maximal' included, not just the interior.
    it "logit/logistic round-trips an interior ground colour" $
      mapM_
        ( \p ->
            getInterval (logisticInterval (logitInterval (mkInterval p)))
              `shouldSatisfy` approx p
        )
        [0.02, 0.5, 0.97]

    it "logClosed/unLogClosed round-trips Minimal" $
      unLogClosed (logClosed Minimal) `shouldBe` (Minimal :: ClosedInterval)

    it "logClosed/unLogClosed round-trips Maximal" $
      unLogClosed (logClosed Maximal) `shouldBe` (Maximal :: ClosedInterval)

    it "logClosed/unLogClosed round-trips an interior Graded value" $
      mapM_
        ( \p -> case unLogClosed (logClosed (Graded (mkInterval p))) of
            Graded iv -> getInterval iv `shouldSatisfy` approx p
            other -> expectationFailure ("expected Graded, got " <> show other)
        )
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
