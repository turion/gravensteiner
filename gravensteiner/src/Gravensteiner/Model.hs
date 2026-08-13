{-# LANGUAGE DuplicateRecordFields #-}


module Gravensteiner.Model where

-- uuid
import Data.UUID (UUID)

-- text
import Data.Text (Text)

-- time

import Data.Functor.Const (Const (..))
import Data.Functor.Identity (Identity (..))
import Data.Kind (Type)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Time (Day, Year)

newtype UUIDOf a = UUIDOf {unUUIDOf :: UUID}
  deriving (Show, Eq, Ord)

data NoUUIDOf a = NoUUID
  deriving (Show, Eq)

data Person (uuidOf :: Type -> Type) = Person
  { name :: Text
  , uuid :: uuidOf (Person uuidOf)
  }

-- | A number assumed to be between 0 and 1
newtype Interval = Interval {getInterval :: Double}
  deriving (Show, Eq, Ord, Num, Fractional, Floating)

data Colours = Colours
  { yellow :: Interval
  , red :: Interval
  , green :: Interval
  }
  deriving (Show, Eq)

data Fruit p (uuidOf :: Type -> Type) = Fruit
  { colours :: p Colours
  , russet :: p Interval
  , -- Further properties can be added here, such as size, shape, etc.
    uuid :: uuidOf (Fruit p uuidOf)
  }

data Collection (uuidOf :: Type -> Type) p = Collection
  { fruits :: [Fruit p uuidOf]
  , date :: p Day
  , tree :: Tree p uuidOf
  , uuid :: uuidOf (Collection p uuidOf)
  }

data Tree (uuidOf :: Type -> Type) p = Tree
  { planted :: p Year
  , uuid :: uuidOf (Tree p uuidOf)
  }

class HasUUID a where
  uuidLens :: (Functor f) => (uuidOf1 a -> f (uuidOf2 a)) -> a (uuidOf1 a) -> f (a (uuidOf2 a))

getUUID :: (HasUUID a) => a (uuidOf a) -> uuidOf a
getUUID = getConst . uuidLens Const

overUUID :: (HasUUID a) => (uuidOf1 a -> uuidOf2 a) -> a (uuidOf1 a) -> a (uuidOf2 a)
overUUID f = runIdentity . uuidLens (Identity . f)

setUUID :: (HasUUID a) => uuidOf2 a -> a (uuidOf1 a) -> a (uuidOf2 a)
setUUID newUUID = overUUID (const newUUID)

newtype UUIDMap (a :: (Type -> Type) -> Type) = UUIDMap {getUUIDMap :: Map UUID (a (NoUUIDOf a))}

lookup :: (HasUUID a) => UUIDOf a -> UUIDMap a -> Maybe (a (UUIDOf a))
lookup uuid'@(UUIDOf uuid) (UUIDMap m) = fmap (setUUID uuid') (Map.lookup uuid m)

data Database = Database
  { people :: UUIDMap Person
  , collections :: UUIDMap Collection
  , trees :: UUIDMap Tree
  }
