{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE StandaloneDeriving #-}

{- | Delayed sampling, following Murray, Lundén, Kudlicka, Broman & Schön,
  /Delayed Sampling and Automatic Rao-Blackwellization of Probabilistic Programs/
  (<https://arxiv.org/abs/1708.07787>).

  Ported from the @dev_delayed_sampling@ branch of
  <https://github.com/turion/monad-bayes>, where this lived inside
  @monad-bayes@ itself. The module path is kept so it can be upstreamed again.
  The @FIXME@ comments are the original author's; they are triaged in @todo/@.
-}
module Control.Monad.Bayes.DelayedSampling where

import Control.Applicative (asum)
import Control.Monad (forM_, void, (>=>))
import Control.Monad.Bayes.Class hiding (Distribution)
import Control.Monad.IO.Class (MonadIO (liftIO))
import Control.Monad.Trans.Class
import Control.Monad.Trans.Except hiding (except)
import Control.Monad.Trans.State.Strict
import Data.Functor.Compose (Compose (..))
import Data.IntMap.Strict (IntMap)
import Data.IntMap.Strict qualified as IntMap
import Data.Maybe (fromMaybe)
import Data.Typeable (Typeable, cast)
import Statistics.Function (square)
import Unsafe.Coerce (unsafeCoerce)
import Prelude hiding (unzip)

newtype Variable a = Variable {getVariable :: Int}
  deriving (Show, Eq)

data SomeVariable = forall a. (Typeable a, Eq a, Show a) => SomeVariable {getSomeVariable :: Variable a}

deriving instance Show SomeVariable

instance Eq SomeVariable where
  SomeVariable var1 == SomeVariable var2 = (Just var1 ==) $ cast var2

-- FIXME do I need const here and realized later? Or can I get away with only variables?
-- I probably need const here still in order to deal with a num instance for value
-- Would be nice to have Functor & Applicative, but that is hard because we also need typeable
-- FIXME It would be great if I could get some kind of HOAS going here so I don't need to look up and rename variables all the time
data Value a where
  Var :: (Typeable a, Eq a, Show a) => Variable a -> Value a
  Const :: a -> Value a
  -- FIXME not sure whether I should put numerical expressions here or in the distributions
  Sum :: (Typeable a, Eq a, Show a) => Variable a -> Value a -> Value a
  Product :: (Typeable a, Eq a, Show a, Num a) => a -> Variable a -> Value a

-- FIXME we could easily implement negate etc. on constants, and fail on variables for now
instance (Num a) => Num (Value a) where
  Var v + value = Sum v value
  _ + _ = error "Value.+: Not implemented"
  fromInteger = Const . fromInteger
  Const a * Var v = Product a v
  _ * _ = error "Value.*: Not implemented"
  negate = error "Value.negate: Not implemented"
  abs = error "Value.abs: Not implemented"
  signum = error "Value.signum: Not implemented"

instance (Fractional a) => Fractional (Value a) where
  fromRational = Const . fromRational
  (/) = error "Value./: Not implemented"

class Subst f where
  subst :: Variable a -> a -> f b -> f b

instance Subst Value where
  -- FIXME I don't know better than unsafeCoerce here. Is there no type safe way to do this?
  subst (Variable i) a (Var (Variable i')) | i == i' = Const $ unsafeCoerce a
  subst _ _ value@(Var _) = value
  subst _ _ value@(Const _) = value
  -- FIXME Need to implement more Num patterns for this to work
  subst (Variable _) _ (Sum (Variable _) _) = error "Not yet implemented"
  subst (Variable i) a (Product a' (Variable i')) | i == i' = unsafeCoerce $ Const $ unsafeCoerce a * a'
  subst _ _ value@(Product _ _) = value

class GetParents f where
  getParents :: f a -> [SomeVariable]

instance GetParents Value where
  getParents (Var var) = [SomeVariable var]
  getParents (Const _) = []
  -- FIXME I don't know whether this is the right approach. Should expressions have
  getParents (Sum var val) = SomeVariable var : getParents val
  getParents (Product _ var) = [SomeVariable var]

deriving instance (Show a) => Show (Value a)

deriving instance (Eq a) => Eq (Value a)

-- FIXME: Use syb (or recursion-schemes?) to push variable indices by an Int

-- FIXME Maybe I should put the functor bla etc. here?
-- Or parametrize distribution constructors over a?
data Distribution a where
  Normal :: Value Double -> Value Double -> Distribution Double
  Normal2 :: Value (Double, Double) -> Distribution Double
  Beta :: Value Double -> Value Double -> Distribution Double

-- FIXME syb?
instance Subst Distribution where
  subst v a (Normal val1 val2) = Normal (subst v a val1) (subst v a val2)
  subst v a (Beta val1 val2) = Beta (subst v a val1) (subst v a val2)
  subst v a (Normal2 val) = Normal2 $ subst v a val

deriving instance Show (Distribution a)

deriving instance Eq (Distribution a)

pdf :: (MonadDistribution m) => Distribution a -> a -> DelayedSamplingT m (Log Double)
pdf (Normal (Const mean) (Const variance)) a = do
  pure $ normalPdf mean (sqrt variance) a
pdf (Beta _alpha _beta) _ = throw NotImplemented
pdf _ _ = throw NotMarginal

instance GetParents Distribution where
  getParents (Normal val1 val2) = getParents val1 <> getParents val2
  getParents (Normal2 val) = getParents val
  getParents (Beta val1 val2) = getParents val1 <> getParents val2

data SomeDistribution = forall a. (Typeable a) => SomeDistribution {getSomeDistribution :: Distribution a}

deriving instance Show SomeDistribution

instance Eq SomeDistribution where
  SomeDistribution dist1 == SomeDistribution dist2 = (Just dist1 ==) $ cast dist2

-- FIXME If I understand it correctly, marginal distributions never have dependencies on variables.
-- If that is right, there ought to be a type tag in Distribution saying which kind of values can occur,
-- and a function marginalize that makes a marginal distribution by removing these dependencies.
data Node a
  = Initialized
      { initialDistribution :: Distribution a
      , marginalDistribution :: Maybe (Distribution a)
      }
  | Realized a
  deriving (Show, Eq)

instance Subst Node where
  subst var a Initialized {initialDistribution, marginalDistribution} =
    Initialized
      { initialDistribution = subst var a initialDistribution
      , -- FIXME if initialDistribution had a substitution, marginalDistribution shouldn't have one.
        -- Need to marginalize instead, which in fact only copies the initialDistribution with the removal.
        -- In fact, original algo doesn't require a substitution in initialDistribution, only in marginalDistribution.
        marginalDistribution = subst var a <$> marginalDistribution
      }
  subst _ _ node@(Realized _) = node

instance GetParents Node where
  getParents Initialized {initialDistribution} = getParents initialDistribution
  getParents (Realized _) = []

currentDistribution :: Node a -> Maybe (Distribution a)
currentDistribution Initialized {initialDistribution, marginalDistribution} = Just $ fromMaybe initialDistribution marginalDistribution
currentDistribution (Realized _) = Nothing

-- FIXME syb?
-- FIXME this is not entirely true: if it's a variable which resolves to a realized node, it's also terminal.
-- So I have to make sure when realizing a node that I replace all occurrences of its variable with the value.
-- In fact, one could delete the realized node from the graph.
-- Else, I could make this here a Distribution a -> DelayedSamplingT m Bool and lookup every time
isTerminalDistribution :: Distribution a -> Bool
isTerminalDistribution (Normal (Const _) (Const _)) = True
isTerminalDistribution (Beta (Const _) (Const _)) = True
isTerminalDistribution _ = False

data SomeNode = forall a. (Eq a, Show a, Typeable a) => SomeNode {getSomeNode :: Node a}

substSome :: Variable a -> a -> SomeNode -> SomeNode
substSome v a SomeNode {getSomeNode} = SomeNode $ subst v a getSomeNode

getParentsSome :: SomeNode -> [SomeVariable]
getParentsSome SomeNode {getSomeNode} = getParents getSomeNode

deriving instance Show SomeNode

instance Eq SomeNode where
  SomeNode node1 == SomeNode node2 = maybe False (node1 ==) (cast node2)

castNode :: (Typeable a) => SomeNode -> Maybe (Node a)
castNode (SomeNode node) = cast node

data Graph = Graph
  { nodes :: IntMap SomeNode
  , maxKey :: Int
  }
  deriving (Show, Eq)

onNodes :: (IntMap SomeNode -> IntMap SomeNode) -> Graph -> Graph
onNodes f Graph {nodes, maxKey} = Graph {nodes = f nodes, maxKey}

empty :: Graph
empty = Graph mempty 0

checkEveryNode :: (forall a. Node a -> Maybe b) -> Graph -> Maybe (Int, b)
checkEveryNode f = asum . fmap (\(n, SomeNode {getSomeNode}) -> (n,) <$> f getSomeNode) . IntMap.toAscList . nodes

atMostOneParent :: Graph -> Maybe (Int, [SomeVariable])
atMostOneParent = checkEveryNode atMostOneParentNode
  where
    atMostOneParentNode :: Node a -> Maybe [SomeVariable]
    atMostOneParentNode = currentDistribution >=> atMostOneParentDistribution

    atMostOneParentDistribution :: Distribution a -> Maybe [SomeVariable]
    atMostOneParentDistribution (Normal (Var var1) (Var var2)) = Just [SomeVariable var1, SomeVariable var2]
    atMostOneParentDistribution (Beta (Var var1) (Var var2)) = Just [SomeVariable var1, SomeVariable var2]
    atMostOneParentDistribution _ = Nothing

data ResolvedVariable
  = forall a.
  (Typeable a, Show a, Eq a) =>
  ResolvedVariable
  { variable :: Variable a
  , node :: Node a
  }

deriving instance Show ResolvedVariable

instance Eq ResolvedVariable where
  ResolvedVariable var1 _ == ResolvedVariable var2 _ = getVariable var1 == getVariable var2

resolve :: (Monad m, Typeable a, Eq a, Show a) => Variable a -> DelayedSamplingT m ResolvedVariable
resolve variable = do
  node <- lookupVar variable
  pure ResolvedVariable {variable, node}

unsafeResolvedVariable :: Int -> SomeNode -> ResolvedVariable
unsafeResolvedVariable i SomeNode {getSomeNode} =
  ResolvedVariable
    { variable = Variable i
    , node = getSomeNode
    }

-- FIXME should be variable, not Int
data Error
  = IndexOutOfBounds Int
  | TypesInconsistent Int
  | AlreadyRealized ResolvedVariable
  | NotMarginal
  | HasMarginalizedChildren ResolvedVariable
  | MultipleParents Int [SomeVariable]
  | ParentNotMarginalised Int Int -- FIXME need to implement check for that
  | IncorrectParent Int Int
  | NoParent ResolvedVariable
  | UnsupportedConditioning SomeDistribution SomeDistribution
  | NotImplemented
  | -- | Only exists for MonadFail
    Fail String

data ErrorTrace = ErrorTrace
  { error_ :: Error
  , trace :: [String]
  }
  deriving (Show, Eq)

deriving instance Eq Error

deriving instance Show Error

newtype DelayedSamplingT m a = DelayedSamplingT {getDelayedSamplingT :: ExceptT ErrorTrace (StateT Graph m) a}
  deriving (Functor, Applicative, Monad, MonadIO)

instance MonadTrans DelayedSamplingT where
  lift = DelayedSamplingT . lift . lift

instance (Monad m) => MonadFail (DelayedSamplingT m) where
  fail = throw . Fail

throw :: (Monad m) => Error -> DelayedSamplingT m a
throw = DelayedSamplingT . throwE . flip ErrorTrace []

tryElse :: (Monad m) => Error -> Maybe a -> DelayedSamplingT m a
tryElse e = maybe (throw e) pure

maybeThrow :: (Monad m) => Maybe Error -> DelayedSamplingT m ()
maybeThrow = mapM_ throw

except :: (Monad m) => Either Error a -> DelayedSamplingT m a
except = either throw pure

-- FIXME use regularly, at least in tests
ensureConsistency :: (Monad m) => DelayedSamplingT m ()
ensureConsistency = do
  graph <- DelayedSamplingT $ lift get
  maybeThrow $ uncurry MultipleParents <$> atMostOneParent graph

addTrace :: (Functor m) => String -> DelayedSamplingT m a -> DelayedSamplingT m a
addTrace msg = DelayedSamplingT . withExceptT (\errortrace@ErrorTrace {trace} -> errortrace {trace = msg : trace}) . getDelayedSamplingT

-- FIXME look into lenses
onNode :: (Monad m, Eq a, Show a, Typeable a) => StateT (Node a) (Either Error) b -> Variable a -> DelayedSamplingT m b
onNode action (Variable i) = do
  graph <- DelayedSamplingT $ lift $ gets nodes
  (b, graph') <- except $ getCompose $ IntMap.alterF (Compose . maybe (Left (IndexOutOfBounds i)) (maybe (Left (TypesInconsistent i)) (fmap (fmap (Just . SomeNode)) . runStateT action) . castNode)) i graph
  DelayedSamplingT $ lift $ modify $ onNodes $ const graph'
  pure b

lookupVar :: (Monad m, Typeable a, Eq a, Show a) => Variable a -> DelayedSamplingT m (Node a)
lookupVar = onNode get

-- FIXME all these are probably mean that I should use sequences for variables.
-- FIXME and named variables as well

modifyListSafe :: Int -> (a -> (Maybe a, b)) -> [a] -> Maybe ([a], b)
modifyListSafe i f as = case splitAt i as of
  (_prefix, []) -> Nothing
  (prefix, a : suffix) -> let (aMaybe, b) = f a in Just (prefix <> (fromMaybe a aMaybe : suffix), b)

getParent :: (Monad m, Eq a, Show a, Typeable a) => Variable a -> DelayedSamplingT m (Maybe SomeVariable)
getParent var = addTrace "getParent" $ do
  parents <- flip onNode var $ gets getParents
  case parents of
    [] -> pure Nothing
    [parent] -> pure $ Just parent
    _ -> throw $ MultipleParents (getVariable var) parents

-- unsafe: doesn't check whether already realized
putRealized :: (Typeable a, Monad m, Show a, Eq a) => a -> Variable a -> DelayedSamplingT m ()
putRealized a var = do
  onNode (put $ Realized a) var

-- DelayedSamplingT $ lift $ modify $ Graph . map (substSome var a) . nodes

-- FIXME also replace all variables in the distributions by the value

-- FIXME possible return type could be DelayedSamplingT m (Distribution a), returning the marginal distribution
lookupTerminal :: (Monad m, Typeable a, Eq a, Show a) => Variable a -> DelayedSamplingT m (Node a)
lookupTerminal var = addTrace "lookupTerminal" $ do
  node <- lookupVar var
  -- Check that all children are not marginalized
  case node of
    Initialized {marginalDistribution = Just _} -> do
      children <- lookupChildren var
      forM_ children $ \ResolvedVariable {node = childNode} -> case childNode of
        Initialized {marginalDistribution = Nothing} -> pure ()
        Initialized {marginalDistribution = Just _} -> throw . HasMarginalizedChildren =<< resolve var
        (Realized _) -> addTrace "The child is " . throw . AlreadyRealized =<< resolve var
    Initialized {} -> throw NotMarginal
    (Realized _) -> throw . AlreadyRealized =<< resolve var
  -- FIXME it would be great if this had a proof term, i.e. the marginal distribution or whatever is needed for the next function
  pure node

lookupChildren :: (Monad m, Typeable a, Eq a, Show a) => Variable a -> DelayedSamplingT m [ResolvedVariable]
lookupChildren var = do
  nodes <- DelayedSamplingT $ lift $ gets nodes
  pure $ fmap (uncurry unsafeResolvedVariable) $ filter ((SomeVariable var `elem`) . getParentsSome . snd) $ IntMap.toAscList nodes

realize :: (MonadDistribution m, Typeable a, Show a, Eq a) => Variable a -> a -> DelayedSamplingT m a
realize var a = addTrace "realize" $ do
  Initialized {initialDistribution, marginalDistribution = Just _} <- lookupTerminal var
  parentMaybe <- getParent var
  forM_ parentMaybe $ \SomeVariable {getSomeVariable = parentVar} -> do
    parent <- lookupVar parentVar
    case parent of
      Initialized {initialDistribution = parentInitialDist, marginalDistribution = Just parentDist} -> do
        parentDist' <- conditionDist a initialDistribution parentVar parentDist
        onNode (put Initialized {initialDistribution = parentInitialDist, marginalDistribution = Just parentDist'}) parentVar
      -- FIXME Now I should sever the parent/child connection, but I can't do that because I alwas use the initial dist for that.
      -- Either mutate the initial dist then or change the way how I look up parents
      Initialized {marginalDistribution = Nothing} -> addTrace "its parent" $ throw NotMarginal
      Realized _ -> pure ()

  children <- lookupChildren var
  putRealized a var
  forM_ children $ \ResolvedVariable {variable} -> marginalize variable
  pure a

marginalize :: (Monad m, Eq a, Show a, Typeable a) => Variable a -> DelayedSamplingT m ()
marginalize var = addTrace "marginalize" $ do
  parentMaybe <- getParent var
  node <- lookupVar var
  SomeVariable {getSomeVariable = parentVar} <- maybe (throw . NoParent =<< resolve var) pure parentMaybe
  parent <- lookupVar parentVar
  case node of
    Initialized {initialDistribution} -> do
      marginalDistribution <-
        Just <$> case parent of
          Realized b -> pure $ subst parentVar b initialDistribution
          Initialized {marginalDistribution = Just parentDistribution} -> do
            marginalizeDistribution initialDistribution parentDistribution
          Initialized {marginalDistribution = Nothing} -> throw NotMarginal
      onNode (put node {marginalDistribution}) var
    Realized _ -> throw . AlreadyRealized =<< resolve var

-- FIXME I don't check here anymore whether the var is the right one. Should I?
marginalizeDistribution ::
  (Monad m, Typeable a, Typeable b) =>
  -- | Child distribution
  Distribution a ->
  -- | Parent distribution
  Distribution b ->
  DelayedSamplingT m (Distribution a)
marginalizeDistribution (Normal (Var _) (Const variance)) (Normal (Const parentMean) (Const parentVariance)) = pure $ Normal (Const parentMean) (Const $ variance + parentVariance)
marginalizeDistribution (Normal (Product c _var) (Const variance)) (Normal (Const parentMean) (Const parentVariance)) = pure $ Normal (Const $ c * parentMean) (Const $ variance + square c * parentVariance)
marginalizeDistribution childDist parentDist = throw $ UnsupportedConditioning (SomeDistribution childDist) (SomeDistribution parentDist)

conditionDist :: (Monad m, Typeable b, Typeable a) => b -> Distribution b -> Variable a -> Distribution a -> DelayedSamplingT m (Distribution a)
conditionDist b (Normal (Var parentVar') (Const variance)) parentVar (Normal (Const parentMean) (Const parentVariance)) =
  if parentVar == parentVar'
    then
      let precision = 1 / variance + 1 / parentVariance
          newMean = (b / variance + parentMean / parentVariance) / precision
       in pure $ Normal (Const newMean) (Const $ 1 / precision)
    else throw $ IncorrectParent (getVariable parentVar) (getVariable parentVar')
conditionDist b (Normal (Product c parentVar') (Const variance)) parentVar (Normal (Const parentMean) (Const parentVariance)) =
  if parentVar == parentVar'
    then
      if c == 0
        then pure (Normal (Const parentMean) (Const parentVariance)) -- FIXME make this a special case of below formula
        else
          let precision = 1 / variance + 1 / (square c * parentVariance)
              newMean = (b / variance + parentMean / (c * parentVariance)) / precision
           in pure $ Normal (Const $ newMean / c) (Const $ 1 / (square c * precision))
    else throw $ IncorrectParent (getVariable parentVar) (getVariable parentVar')
conditionDist _ childDist _ parentDist = throw $ UnsupportedConditioning (SomeDistribution childDist) (SomeDistribution parentDist)

value :: (MonadDistribution m, Typeable a, Show a, Eq a) => Variable a -> DelayedSamplingT m a
value var = addTrace "value" $ do
  graft var
  sample var

sample :: (MonadDistribution m, Typeable a, Show a, Eq a) => Variable a -> DelayedSamplingT m a
sample var = addTrace "sample" $ do
  node <- lookupVar var
  case node of
    Realized a -> pure a
    _ -> do
      -- FIXME It's a bit inefficient to lookup twice
      Initialized {marginalDistribution = Just marginalDistribution} <- lookupTerminal var
      a <- sampleMarginal marginalDistribution
      realize var a
      pure a

sampleMarginal :: (MonadDistribution m) => Distribution a -> DelayedSamplingT m a
sampleMarginal =
  addTrace "sampleMarginal" . \case
    (Normal (Const mu) (Const variance)) -> lift $ normal mu $ sqrt variance
    (Beta (Const a) (Const b)) -> lift $ beta a b
    _ -> throw NotMarginal -- FIXME would be good to avoid this type in the first place with the right distribution type

-- sample (Fmap f value) = f <$> sample value
-- sample (Ap f value) = sample f <*> sample value

runDelayedSamplingT :: (Functor m) => DelayedSamplingT m a -> m (Either ErrorTrace a, Graph)
runDelayedSamplingT = flip runStateT empty . runExceptT . getDelayedSamplingT

evalDelayedSamplingT :: (Functor m) => DelayedSamplingT m a -> m (Either ErrorTrace a)
evalDelayedSamplingT = fmap fst . runDelayedSamplingT

initialize :: (Monad m, Typeable a, Show a, Eq a) => Distribution a -> DelayedSamplingT m (Variable a)
initialize initialDistribution = DelayedSamplingT $ lift $ do
  Graph nodes maxKey <- get
  let marginalDistribution = if null $ getParents initialDistribution then Just initialDistribution else Nothing
      maxKey' = maxKey + 1
  put $
    Graph
      { nodes = IntMap.insert maxKey (SomeNode Initialized {initialDistribution, marginalDistribution}) nodes
      , maxKey = maxKey'
      }
  pure $ Variable maxKey

normalDS ::
  (Monad m) =>
  -- | Mean
  Value Double ->
  -- | Variance! Not stddev
  Value Double ->
  DelayedSamplingT m (Variable Double)
normalDS mean variance = initialize $ Normal mean variance

-- FIXME I'd like to observe on Value a, but I don't know how to do that with var1 + var2
-- FIXME In the paper, the observe thing has type a -> DelayedSamplingT m a -> DelayedSamplingT m (),
-- so one doesn't do bad things to the variable. Is this wise or is this extra flexibility ok?
observe :: (MonadMeasure m, Typeable a, Show a, Eq a) => Variable a -> a -> DelayedSamplingT m ()
observe variable a = addTrace "observe" do
  graft variable
  Initialized {marginalDistribution = Just marginalDistribution} <- lookupTerminal variable
  realize variable a
  p <- pdf marginalDistribution a
  lift $ score p

graft :: (Monad m, Typeable a, Eq a, Show a, MonadDistribution m) => Variable a -> DelayedSamplingT m ()
graft var = addTrace "graft" do
  node <- lookupVar var
  case node of
    Initialized {marginalDistribution = Just _} -> do
      children <- lookupChildren var
      forM_ children $ \resolved@ResolvedVariable {node = childNode, variable = childVar} -> case childNode of
        Initialized {marginalDistribution = Just _} -> prune childVar
        Initialized {marginalDistribution = Nothing} -> pure ()
        Realized _ -> addTrace "one of the children while grafting" $ throw $ AlreadyRealized resolved
    Initialized {marginalDistribution = Nothing} -> do
      parentMaybe <- getParent var
      forM_ parentMaybe $ \SomeVariable {getSomeVariable = parentVar} -> graft parentVar
      marginalize var
    Realized _ -> throw . AlreadyRealized =<< resolve var

prune :: (Monad m, Typeable a, Eq a, Show a, MonadDistribution m) => Variable a -> DelayedSamplingT m ()
prune var = addTrace "prune" do
  node <- lookupVar var
  case node of
    Initialized {marginalDistribution = Just _} -> do
      children <- lookupChildren var
      forM_ children $ \resolved@ResolvedVariable {node = childNode, variable = childVar} -> case childNode of
        Initialized {marginalDistribution = Just _} -> prune childVar
        Initialized {marginalDistribution = Nothing} -> pure ()
        Realized _ -> addTrace "one of the children while pruning" $ throw $ AlreadyRealized resolved
    _ -> throw NotMarginal
  void $ sample var

-- FIXME this is just a step of marginalizing and might have a better name in the paper
-- FIXME unsafe, doesn't check whether already realized
setMarginalized :: (Monad m, Typeable a, Show a, Eq a) => Variable a -> Distribution a -> DelayedSamplingT m ()
setMarginalized variable marginalDistribution = flip onNode variable $ do
  node <- get
  case node of
    Realized _ -> error "Already realized" -- FIXME should really have a local monad with error
    initialized@Initialized {} -> put initialized {marginalDistribution = Just marginalDistribution}

-- FIXME this should be linear in the variable

{- | Attempts to remove a realized variable from the graph and substitute/inline its value into all references to it.
  Returns its success. (It can fail if it is not realized.)
-}
deallocateRealized :: (Monad m, Typeable a, Eq a, Show a) => Variable a -> DelayedSamplingT m Bool
deallocateRealized var = do
  node <- lookupVar var
  case node of
    Realized a -> do
      DelayedSamplingT $ lift $ modify $ onNodes $ IntMap.delete (getVariable var) . IntMap.map (substSome var a)
      pure True
    _ -> pure False

debugGraph :: (Monad m) => DelayedSamplingT m Graph
debugGraph = DelayedSamplingT $ lift get

debugGraphIO :: (MonadIO m) => DelayedSamplingT m ()
debugGraphIO = DelayedSamplingT $ liftIO (putStrLn "Graph:") >> lift (gets nodes) >>= (liftIO . mapM_ print)
