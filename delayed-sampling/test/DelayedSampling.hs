{-# LANGUAGE NamedFieldPuns #-}

module DelayedSampling where

import Control.Monad (forM, forM_)
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
      (Right (), p) <- sampleIO $ runWeightedT $ evalDelayedSamplingT $ do
        a <- normalDS (Const 0) (Const 1)
        observe a 1
      p `shouldBe` normalPdf 0 1 1

    it "sample reproduces observed value" $ do
      (result, _) <- sampleIO $ runWeightedT $ evalDelayedSamplingT $ do
        a <- normalDS (Const 0) (Const 1)
        observe a 1
        sample a
      a <- shouldBeRight result
      a `shouldBe` 1

    it "throws an error when observing the same variable twice" $ do
      (result, _) <- sampleIO $ runWeightedT $ evalDelayedSamplingT $ do
        a <- normalDS (Const 0) (Const 1)
        observe a 1
        observe a 2
      AlreadyRealized ResolvedVariable {variable} <- error_ <$> shouldBeLeft result
      getVariable variable `shouldBe` 0

    it "can observe variables in a hierarchical model and weight correctly" $ do
      (_, p) <- sampleIO $ runWeightedT $ runDelayedSamplingT $ do
        a <- normalDS (Const 0) (Const 2)
        b <- normalDS (Var a) (Const 1)
        observe b 1
        sample a
      p `shouldBe` normalPdf 0 (sqrt 3) 1

  describe "examples" $ do
    describe "table 1" $ do
      it "reproduces the first program" $ do
        (result, p) <- sampleIO $ runWeightedT $ evalDelayedSamplingT $ do
          x <- normalDS 0 1
          y <- normalDS (Var x) 1
          z <- normalDS (Var y) 1
          observe z 3
          -- Have to call value for x since it isn't terminal
          (,) <$> value x <*> sample y
        (x, y) <- shouldBeRight result
        -- FIXME what to test on x and y? Maybe do a few debugGraph and look at them
        pure ()
    it "reproduces Figure 2 from the paper" $ do
      (result, _) <- sampleIO $ runWeightedT $ evalDelayedSamplingT $ do
        a <- normalDS (Const 0) (Const 1)
        b <- normalDS (Var a) (Const 1)
        c <- normalDS (Var b) (Const 1)
        d <- normalDS (Var b) (Const 1)
        _ <- normalDS (Var c) (Const 1)
        _ <- normalDS (Var c) (Const 1)
        graft c
        graph1 <- debugGraph
        graft d
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
            observe xVar x
            True <- deallocateRealized xVar
            pure ()
          sample posVar
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
            observe xVar x
            True <- deallocateRealized xVar
            pure ()
          sample velVar
        pure $ (,vel) <$> result
      result `shouldSatisfy` \(inferred, sampled) -> abs (inferred - sampled) < 5 / sqrt 100000
