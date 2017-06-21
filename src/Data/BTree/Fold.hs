{-# LANGUAGE GADTs #-}
module Data.BTree.Fold where

import Prelude hiding (foldr, foldl)

import Data.BTree.Alloc.Class
import Data.BTree.Primitives

import Control.Applicative ((<$>))
import Control.Monad (liftM2)

import Data.Monoid (Monoid, (<>), mempty)

import qualified Data.Foldable as F
import qualified Data.Map as M

--------------------------------------------------------------------------------

{-| Perform a right-associative fold over the tree. -}
foldr :: (AllocM m, Key k, Value a)
      => (a -> b -> b) -> b -> Tree k a -> m b
foldr _ x (Tree _ Nothing) = return x
foldr f x (Tree h (Just nid)) = foldrId (liftM2 f) (return x) h nid

foldrId :: (AllocM m, Key k, Value a)
        => (m a -> m b -> m b) -> m b -> Height h -> NodeId h k a -> m b
foldrId f x h nid = readNode h nid >>= foldrNode f x h

foldrNode :: (AllocM m, Key k, Value a)
          => (m a -> m b -> m b) -> m b -> Height h -> Node h k a -> m b
foldrNode f x _ (Leaf items) = M.foldr f x (return <$> items)
foldrNode f x h (Idx idx) = F.foldr (\nid x' -> foldrId f x' (decrHeight h) nid) x idx

--------------------------------------------------------------------------------

foldMap :: (AllocM m, Key k, Value a, Monoid c)
      => (a -> c) -> Tree k a -> m c
foldMap f = foldr ((<>) . f) mempty

toList :: (AllocM m, Key k, Value a)
      => Tree k a -> m [a]
toList = foldr (:) []

--------------------------------------------------------------------------------
