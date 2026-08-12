{-# LANGUAGE NamedFieldPuns #-}

module DelayedSampling where

import Control.Monad (forM, forM_, unless, void)
import Control.Monad.Bayes.Class
import Control.Monad.Bayes.DelayedSampling
import Control.Monad.Bayes.Sampler.Strict
import Control.Monad.Bayes.Weighted (runWeightedT)
import Data.IntMap (toAscList)
import Data.Typeable (cast)
import Test.HUnit (assertFailure)
import Test.Hspec

shouldBeRight :: (Show e) => Either e a -> IO a
shouldBeRight = either (\e -> assertFailure $ ("Expected Right, got Left (" <> (show e ++ ")"))) pure

shouldBeLeft :: (Show b) => Either a b -> IO a
shouldBeLeft = either pure $ \b -> assertFailure $ ("Expected Left, got Right (" <> (show b ++ ")"))

{- | Check the graph invariants after the action, so that every test below
  doubles as a test of 'ensureConsistency'.
-}
checked :: (Monad m) => DelayedSamplingT m a -> DelayedSamplingT m a
checked action = action <* ensureConsistency

test :: SpecWith ()
test = describe "DelayedSampling" $ do
  describe "sample" $ do
    it "can sample" $ do
      val <- (shouldBeRight =<<) $ sampleIO $ evalDelayedSamplingT $ normalDS (Const 0) (Const 1)
      val `shouldBe` val -- Forces and checks whether not NaN
    it "sample the same value for the same variable every time" $ do
      (a, a') <- (shouldBeRight =<<) $ sampleIO $ evalDelayedSamplingT $ do
        a <- normalDS (Const 0) (Const 1)
        (,) <$> sample a <*> sample a
      a `shouldBe` a'

    it "samples the same value as a direct draw" $ do
      val1 <- (shouldBeRight =<<) $ sampleIOfixed $ evalDelayedSamplingT $ do
        a <- normalDS (Const 0) (Const 1)
        sample a
      val2 <- sampleIOfixed $ normal 0 1
      val1 `shouldBe` val2

    it "samples independent variables like in direct sampling" $ do
      val1 <- (shouldBeRight =<<) $ sampleIOfixed $ evalDelayedSamplingT $ do
        a <- normalDS (Const 0) (Const 1)
        b <- normalDS (Const 10) (Const 1)
        (,) <$> sample a <*> sample b
      val2 <- sampleIOfixed $ do
        a <- normal 0 1
        b <- normal 10 1
        pure (a, b)
      val1 `shouldBe` val2

    it "samples variables in a hierarchical model like in direct sampling" $ do
      val1 <- (shouldBeRight =<<) $ sampleIOfixed $ evalDelayedSamplingT $ do
        a <- addTrace "a" $ normalDS (Const 0) (Const 1)
        b <- addTrace "b" $ normalDS (Var a) (Const 1)
        (,) <$> sample a <*> sample b
      val2 <- sampleIOfixed $ do
        a <- normal 0 1
        b <- normal a 1
        pure (a, b)
      val1 `shouldBe` val2

  describe "observe" $ do
    it "adds a factor of the PDF when observing" $ do
      (result, p) <- sampleIO $ runWeightedT $ evalDelayedSamplingT $ do
        a <- normalDS (Const 0) (Const 1)
        checked $ observe a 1
      shouldBeRight result
      p `shouldBe` normalPdf 0 1 1

    it "sample reproduces observed value" $ do
      (result, _) <- sampleIO $ runWeightedT $ evalDelayedSamplingT $ do
        a <- normalDS (Const 0) (Const 1)
        checked $ observe a 1
        checked $ sample a
      a <- shouldBeRight result
      a `shouldBe` 1

    it "throws an error when observing the same variable twice" $ do
      (result, _) <- sampleIO $ runWeightedT $ evalDelayedSamplingT $ do
        a <- normalDS (Const 0) (Const 1)
        observe a 1
        observe a 2
      err <- error_ <$> shouldBeLeft result
      case err of
        AlreadyRealized ResolvedVariable {variable} -> getVariable variable `shouldBe` 0
        _ -> assertFailure $ ("Expected AlreadyRealized, got " <> show err)

    it "can observe variables in a hierarchical model and weight correctly" $ do
      (result, p) <- sampleIO $ runWeightedT $ evalDelayedSamplingT $ do
        a <- normalDS (Const 0) (Const 2)
        b <- normalDS (Var a) (Const 1)
        checked $ observe b 1
        checked $ sample a
      -- The original test discarded this result, so it could not tell a failing
      -- program from a succeeding one; only the weight was checked.
      void $ shouldBeRight result
      p `shouldBe` normalPdf 0 (sqrt 3) 1

  describe "ensureConsistency" $ do
    it "detects a node with two parents" $ do
      (result, _) <- sampleIO $ runWeightedT $ evalDelayedSamplingT $ do
        a <- normalDS (Const 0) (Const 1)
        b <- normalDS (Const 0) (Const 1)
        -- Two parents inside one affine expression, as in the Kalman filter.
        -- This is the shape the check used to wave through.
        _ <- normalDS (Var a + Const 2 * Var b) (Const 1)
        ensureConsistency
      err <- error_ <$> shouldBeLeft result
      case err of
        MultipleParents i parents -> do
          i `shouldBe` 2
          fmap (\SomeVariable {getSomeVariable} -> getVariable getSomeVariable) parents `shouldBe` [0, 1]
        _ -> assertFailure $ ("Expected MultipleParents, got " <> show err)

    it "detects a marginalized node whose parent is not marginalized (Invariant 1)" $ do
      (result, _) <- sampleIO $ runWeightedT $ evalDelayedSamplingT $ do
        a <- normalDS (Const 0) (Const 1)
        b <- normalDS (Var a) (Const 1)
        c <- normalDS (Var b) (Const 1)
        -- Marginalizing c while b is still only initialized skips a step.
        setMarginalized c $ Normal (Const 0) (Const 3)
        ensureConsistency
      err <- error_ <$> shouldBeLeft result
      err `shouldBe` ParentNotMarginalised 2 1

    it "detects two marginalized children of the same node (Invariant 2)" $ do
      (result, _) <- sampleIO $ runWeightedT $ evalDelayedSamplingT $ do
        a <- normalDS (Const 0) (Const 1)
        b <- normalDS (Var a) (Const 1)
        c <- normalDS (Var a) (Const 1)
        setMarginalized b $ Normal (Const 0) (Const 2)
        setMarginalized c $ Normal (Const 0) (Const 2)
        ensureConsistency
      err <- error_ <$> shouldBeLeft result
      err `shouldBe` MultipleMarginalizedChildren 0 [1, 2]

    it "accepts a node that refers to the same parent twice" $ do
      result <- (shouldBeRight =<<) $ sampleIO $ evalDelayedSamplingT $ do
        a <- normalDS (Const 0) (Const 1)
        _ <- normalDS (Var a) (Var a)
        ensureConsistency
      result `shouldBe` ()

  describe "examples" $ do
    describe "table 1" $ do
      it "reproduces the first program" $ do
        (result, p) <- sampleIO $ runWeightedT $ evalDelayedSamplingT $ do
          x <- normalDS 0 1
          y <- normalDS (Var x) 1
          z <- normalDS (Var y) 1
          checked $ observe z 3
          -- Have to call value for x since it isn't terminal
          checked $ (,) <$> value x <*> sample y
        (x, y) <- shouldBeRight result
        -- The weight is the evidence, i.e. the marginal of z: N(0, 1 + 1 + 1).
        p `shouldBe` normalPdf 0 (sqrt 3) 3
        -- FIXME The posteriors of x and y deserve a statistical test of their own;
        -- forcing them at least catches a NaN. See todo/.
        x `shouldSatisfy` (not . isNaN)
        y `shouldSatisfy` (not . isNaN)
    it "reproduces Figure 2 from the paper" $ do
      (result, _) <- sampleIO $ runWeightedT $ evalDelayedSamplingT $ do
        a <- normalDS (Const 0) (Const 1)
        b <- normalDS (Var a) (Const 1)
        c <- normalDS (Var b) (Const 1)
        d <- normalDS (Var b) (Const 1)
        _ <- normalDS (Var c) (Const 1)
        _ <- normalDS (Var c) (Const 1)
        checked $ graft c
        graph1 <- debugGraph
        checked $ graft d
        graph2 <- debugGraph
        pure (graph1, graph2)
      (graph1, graph2) <- shouldBeRight result
      snd <$> toAscList (nodes graph1)
        `shouldBe` [ SomeNode {getSomeNode = Initialized {initialDistribution = Normal (Const 0) (Const 1), marginalDistribution = Just $ Normal (Const 0) (Const 1)}}
                   , SomeNode {getSomeNode = Initialized {initialDistribution = Normal (Var (Variable 0)) (Const 1), marginalDistribution = Just $ Normal (Const 0) (Const 2)}}
                   , SomeNode {getSomeNode = Initialized {initialDistribution = Normal (Var (Variable 1)) (Const 1), marginalDistribution = Just $ Normal (Const 0) (Const 3)}}
                   , SomeNode {getSomeNode = Initialized {initialDistribution = Normal (Var (Variable 1)) (Const 1), marginalDistribution = Nothing}}
                   , SomeNode {getSomeNode = Initialized {initialDistribution = Normal (Var (Variable 2)) (Const 1), marginalDistribution = Nothing}}
                   , SomeNode {getSomeNode = Initialized {initialDistribution = Normal (Var (Variable 2)) (Const 1), marginalDistribution = Nothing}}
                   ]
      let nodes2 = snd <$> toAscList (nodes graph2)
      c <- case nodes2 !! 2 of
        SomeNode {getSomeNode} -> case cast getSomeNode :: Maybe (Node Double) of
          Just (Realized c) -> pure c
          _ -> assertFailure "Was not realized"
      nodes2
        `shouldBe` [ SomeNode {getSomeNode = Initialized {initialDistribution = Normal (Const 0) (Const 1), marginalDistribution = Just $ Normal (Const 0) (Const 1)}}
                   , SomeNode {getSomeNode = Initialized {initialDistribution = Normal (Var (Variable 0)) (Const 1), marginalDistribution = Just $ Normal (Const $ c * 2 / 3) (Const $ 2 / 3)}}
                   , SomeNode {getSomeNode = Realized c}
                   , -- 1 + 2/3, not 5/3: marginalizeDistribution adds the variances, and the
                     -- two spellings differ in the last ulp.
                     SomeNode {getSomeNode = Initialized {initialDistribution = Normal (Var (Variable 1)) (Const 1), marginalDistribution = Just $ Normal (Const $ c * 2 / 3) (Const $ 1 + 2 / 3)}}
                   , SomeNode {getSomeNode = Initialized {initialDistribution = Normal (Var (Variable 2)) (Const 1), marginalDistribution = Just $ Normal (Const c) (Const 1)}}
                   , SomeNode {getSomeNode = Initialized {initialDistribution = Normal (Var (Variable 2)) (Const 1), marginalDistribution = Just $ Normal (Const c) (Const 1)}}
                   ]

  describe "Markov chains" $ do
    it "can measure a 1d particle 10000 times and arrive at a precise value" $ do
      result <- (shouldBeRight =<<) $ sampleIO $ do
        pos <- normal 0 1
        let ts = [0 .. 9999 :: Int]
        xs <- forM ts $ \_t -> normal pos 1
        (result, _) <- runWeightedT $ evalDelayedSamplingT $ do
          posVar <- normalDS (Const 0) (Const 1)
          forM_ xs $ \x -> do
            xVar <- normalDS (Var posVar) (Const 1)
            checked $ observe xVar x
            -- Not just cleanup: without it the graph grows with every
            -- observation, and lookupChildren scans all of it.
            deallocated <- deallocateRealized xVar
            unless deallocated $ fail "The observed variable should be realized"
          checked $ sample posVar
        pure $ (,pos) <$> result
      result `shouldSatisfy` (\(inferred, sampled) -> abs (inferred - sampled) < 5 / sqrt 10000)

    it "can reproduce a Kalman filter of a 1d particle" $ do
      result <- (shouldBeRight =<<) $ sampleIO $ do
        -- pos <- normal 0 1 -- FIXME Can't deal with multiple parents yet
        let pos = 0
        vel <- normal 0 1
        let ts = [0 .. 99999]
        xs <- forM ts $ \t -> normal (pos + vel * t) 1
        (result, _) <- runWeightedT $ evalDelayedSamplingT $ do
          -- posVar <- normalDS (Const 0) (Const 1)
          velVar <- normalDS (Const 0) (Const 1)
          forM_ (zip ts xs) $ \(t, x) -> do
            -- let mu = Var posVar + Const t * Var velVar
            let mu = Const t * Var velVar
            xVar <- normalDS mu 1
            checked $ observe xVar x
            deallocated <- deallocateRealized xVar
            unless deallocated $ fail "The observed variable should be realized"
          checked $ sample velVar
        pure $ (,vel) <$> result
      result `shouldSatisfy` \(inferred, sampled) -> abs (inferred - sampled) < 5 / sqrt 100000
