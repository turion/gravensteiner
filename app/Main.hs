{-# LANGUAGE OverloadedStrings #-}
module Main where

import Debug.Trace
import Control.Monad.IO.Class (MonadIO (..))
import GHC.Stack (HasCallStack)
import Control.Monad (replicateM, guard)
import Data.String (IsString)
import Data.List (foldl')
import Data.Text (Text)
import Numeric.SpecFunctions
import Data.Map.Strict (Map, toList, alter)
import Numeric.Log (Log (..))
import Control.Monad.Bayes.Class (MonadDistribution (gamma))
import Control.Monad.Bayes.Population (fromWeightedList, proper)
import Control.Monad.Bayes.Weighted (unweighted)
import Control.Monad.Bayes.Sampler.Strict (sampleIO)

newtype Name = Name {getName :: Text}
  deriving (IsString, Eq, Ord, Show)

newtype LongName = LongName {getLongName :: Text}
  deriving (IsString, Eq, Ord)

data SortDescription = SortDescription
  { longName :: LongName
  , alternativeNames :: [LongName] -- Maybe we want to train these as well?
  -- FIXME photos, history, links
  }

-- FIXME I want a set here I guess?
newtype Sorts = Sorts {getSorts :: Map Name SortDescription}

newtype Interval = Interval {getInterval :: Double}
  deriving (Show, Eq, Ord, Num, Fractional, Floating)

interval :: Double -> Maybe Interval
interval i = guard (0 <= i && i <= 1) >> return (Interval i)

newtype Positive = Positive {getPositive :: Double}
  deriving (Show, Eq, Ord, Num, Fractional, Floating)

positive :: Double -> Maybe Positive
positive i = guard (i > 0) >> return (Positive i)

newtype Nonnegative = Nonnegative {getNonnegative :: Double}
  deriving (Show, Eq, Ord, Num, Fractional, Floating)

nonnegative :: Double -> Maybe Nonnegative
nonnegative i = guard (i > 0) >> return (Nonnegative i)

data Colours = Colours
  { yellow :: Interval
  , red :: Interval
  , green :: Interval
  , brown :: Interval
  }

noColours :: Colours
noColours = Colours { red = 0, yellow = 0, green = 0, brown = 0}

completelyRed :: Colours
completelyRed = noColours { red = 1 }

{-
data Beta = Beta
  { alpha :: Nonnegative
  , beta :: Nonnegative -- FIXME name clash
  }

data BetaPrior = BetaPrior
  { productP :: Interval
  , productComplement :: Interval
  , pseudocountBetaPrior :: Nonnegative -- FIXME naming pseudocount same everywhere?
  }
-}

-- FIXME HKD to define priors & observations?

-- FIXME naming
-- FIXME general dirichlet
data DirichletColoursPrior = DirichletColoursPrior
  { yellowPrior :: Nonnegative
  , redPrior :: Nonnegative
  , greenPrior :: Nonnegative
  , brownPrior :: Nonnegative
  , pseudocount :: Nonnegative
  }

data DirichletColours = DirichletColours
  { yellowDirichlet :: Nonnegative
  , redDirichlet :: Nonnegative
  , greenDirichlet :: Nonnegative
  , brownDirichlet :: Nonnegative
  } deriving Show

dirichletColoursNormalizable :: DirichletColoursPrior -> Bool
dirichletColoursNormalizable DirichletColoursPrior { yellowPrior , redPrior , greenPrior , brownPrior , pseudocount }
  = 1 > sum (exp . negate . (/ pseudocount) <$> [yellowPrior , redPrior , greenPrior , brownPrior])

updateDirichletColours :: Colours -> DirichletColoursPrior -> DirichletColoursPrior
updateDirichletColours Colours { yellow , red , green , brown } DirichletColoursPrior { yellowPrior , redPrior , greenPrior , brownPrior , pseudocount } = DirichletColoursPrior
  -- FIXME Is the nonnegative property satisfied? Can I prove it on the type level?
  { yellowPrior = yellowPrior - Nonnegative (log $ getInterval yellow)
  , redPrior = redPrior - Nonnegative (log $ getInterval red)
  , greenPrior = greenPrior - Nonnegative (log $ getInterval green)
  , brownPrior = brownPrior - Nonnegative (log $ getInterval brown)
  , pseudocount = pseudocount + 1
  }

-- unnormalized!
dirichletColoursLikelihood :: DirichletColoursPrior -> DirichletColours -> Log Double
dirichletColoursLikelihood DirichletColoursPrior { yellowPrior , redPrior , greenPrior , brownPrior , pseudocount } DirichletColours
  { yellowDirichlet , redDirichlet , greenDirichlet , brownDirichlet } =
    Exp (negate $ sum $ getNonnegative <$> [yellowPrior * yellowDirichlet, redPrior * redDirichlet , greenPrior * greenDirichlet , brownPrior * brownDirichlet])
      -- FIXME make more efficient with Exp & log
      / (Exp $
          log $
          traceShowWith ("beta to",) $
          traceShowWith ("beta",) (beta $ traceShowWith ("priors", ) (getNonnegative <$> [yellowPrior , redPrior , greenPrior , brownPrior])) ** getNonnegative (traceShowWith ("pc",) (pseudocount))
        )

coloursLikelihood :: DirichletColours -> Colours -> Log Double
coloursLikelihood DirichletColours { yellowDirichlet , redDirichlet , greenDirichlet , brownDirichlet } Colours{ yellow , red , green , brown } = Exp $ log $ -- FIXME make more efficient
  -- FIXME ugly to have all these get*
  product [getInterval yellow ** (getNonnegative yellowDirichlet - 1), getInterval red ** (getNonnegative redDirichlet - 1)  , getInterval green ** (getNonnegative greenDirichlet - 1) , getInterval brown ** (getNonnegative brownDirichlet - 1) ] / (beta (getNonnegative <$> [yellowDirichlet , redDirichlet , greenDirichlet , brownDirichlet]))

gamma11pdf :: Double -> Double
gamma11pdf x = exp (- x)

sampleDirichletColours :: (HasCallStack, MonadDistribution m, MonadIO m) => DirichletColoursPrior -> m DirichletColours
sampleDirichletColours prior@DirichletColoursPrior { yellowPrior , redPrior , greenPrior , brownPrior } = do
  -- let quality = 1000
  let quality = 10
  samples <- replicateM quality $ do
    yellowDirichlet <- Nonnegative <$> gamma 1 1
    redDirichlet <- Nonnegative <$> gamma 1 1
    greenDirichlet <- Nonnegative <$> gamma 1 1
    brownDirichlet <- Nonnegative <$> gamma 1 1
    -- FIXME use weighted properly
    let dirichletColours = DirichletColours { yellowDirichlet , redDirichlet , greenDirichlet , brownDirichlet }
    liftIO $ print $ dirichletColoursLikelihood prior dirichletColours
    return (dirichletColours, dirichletColoursLikelihood prior dirichletColours
      * Exp (sum $ getNonnegative <$> [yellowDirichlet , redDirichlet , greenDirichlet , brownDirichlet]) -- FIXME inverse likelihood of gamma
      -- * Exp (sum $ getNonnegative <$> [yellowPrior , redPrior , greenPrior , brownPrior]) -- FIXME inverse likelihood of gamma
      )
  -- liftIO $ traverse print samples
  unweighted $ proper $ fromWeightedList $ return samples

-- gamma :: Double -> Double
-- gamma = exp . logGamma

beta :: [Double] -> Double
beta as = exp $ sum (logGamma <$> as) - logGamma (sum as)

-- | One specific fruit
data Apple = Apple
  { colours :: Maybe Colours
  -- , overcolour :: Maybe Interval
  -- , weight
  }

data AppleSortPrior = AppleSortPrior
  { sortColours :: DirichletColoursPrior
  , frequency :: Nonnegative -- FIXME These are Dirichlet weights over all sorts!
  }

-- https://en.wikipedia.org/wiki/Conjugate_prior#When_likelihood_function_is_a_continuous_distribution
-- https://en.wikipedia.org/wiki/Dirichlet_distribution#Conjugate_prior_of_the_Dirichlet_distribution
-- Assuming I have no idea because I've ever seen one apple in my life, and only paid half attention.
-- If I expect an apple to be 60% red, it means that 0.6 = exp (- redPrior) => redPrior = - ln 0.6
initialSortColours :: DirichletColoursPrior
initialSortColours = DirichletColoursPrior
  { yellowPrior = - log 0.2
  , redPrior = - log 0.6
  , greenPrior = - log 0.1
  , brownPrior = - log 0.1
  , pseudocount = 0.5
  }
-- FIXME Actually I want to have a prior over that as well? So I can generate better initial apple sorts?
initialAppleSortPrior :: AppleSortPrior
initialAppleSortPrior = AppleSortPrior
  { sortColours = initialSortColours
  , frequency = 0
  }

updateAppleSortPrior :: Apple -> AppleSortPrior -> AppleSortPrior
updateAppleSortPrior Apple {colours} AppleSortPrior { sortColours, frequency } = AppleSortPrior
  { sortColours = maybe id updateDirichletColours colours sortColours
  , frequency = frequency + 1
  }

data Observation = Observation
  { observedSort :: Name
  , observedApple :: Apple
  }

newtype Model = Model {getModel :: Map Name AppleSortPrior}

updateModel :: Observation -> Model -> Model
updateModel Observation { observedApple, observedSort } Model {getModel} = Model $ alter f observedSort getModel
  where
    -- FIXME refactor
    f Nothing = Just $ updateAppleSortPrior observedApple initialAppleSortPrior
    f (Just prior) = Just $ updateAppleSortPrior observedApple prior

-- FIXME how will I keep the model from hallucinating? I need a good general apple prior so I can print a probability that the sort match is correct
identify :: (HasCallStack, MonadDistribution m, MonadIO m) => Apple -> Model -> m Name
identify Apple {colours = Just colours} Model {getModel} = do
  -- FIXME I have to take the frequency & total number into account
  dirichlets <- traverse (sampleDirichletColours . sortColours) getModel
  let likelihoods = flip coloursLikelihood colours <$> dirichlets
  -- FIXME refactor with earlier usage
  liftIO $ print likelihoods
  unweighted $ proper $ fromWeightedList $ return $ toList likelihoods
identify Apple {colours = Nothing} _ = error "not yet supported" -- FIXME should just sample by frequency

type Training = [Observation]

initialTraining :: Training
initialTraining =
  [ Observation "Jonathan" $ Apple {colours = Just $ noColours {red = 0.9, yellow = 0.1}}
  , Observation "Gravensteiner" $ Apple {colours = Just $ noColours {red = 0.6, yellow = 0.4}}
  , Observation "Boskoop" $ Apple {colours = Just noColours {red = 0.3, green = 0.4, brown = 0.3}}
  ]

{- Next steps:
* All relevant apple properties like weight, size, patterns, all shapes...
* Model for reliability of pomologists, photos & books
* ripeness, time of year of observation, location
* Weather influences
-}

main :: IO ()
main = do
  -- FIXME this belongs to a test suite
  if dirichletColoursNormalizable initialSortColours then return () else error "Initial sort colours bad"
  let model = foldl' (flip updateModel) (Model mempty) initialTraining
  sort <- sampleIO $ identify Apple {colours = Just $ noColours {red = 0.9, yellow = 0.1}} model
  print sort
