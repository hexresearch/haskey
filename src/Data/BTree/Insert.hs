{-# LANGUAGE DataKinds           #-}
{-# LANGUAGE GADTs               #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Data.BTree.Insert where

import           Data.BTree.Alloc.Class
import           Data.BTree.Primitives
import           Data.BTree.TwoThree

import           Data.Map (Map)
import qualified Data.Map as M
import           Data.Traversable (traverse)

--------------------------------------------------------------------------------

checkSplitIdx ::
       Index key (NodeId height key val)
    -> Index key (Node ('S height) key val)
checkSplitIdx idx
    -- In case the branching fits in one index node we create it.
    | indexNumKeys idx <= maxIdxKeys
    = indexFromList [] [Idx idx]
    -- Otherwise we split the index node.
    | (leftIdx, middleKey, rightIdx) <- splitIndex idx
    = indexFromList [middleKey] [Idx leftIdx, Idx rightIdx]

checkSplitLeaf :: Key key
    => Map key val
    -> Index key (Node 'Z key val)
checkSplitLeaf items
    | M.size items <= maxLeafItems
    = indexFromList [] [Leaf items]
    | (leftItems, middleKey, rightItems) <- splitLeaf items
    = indexFromList [middleKey] [Leaf leftItems, Leaf rightItems]

checkSplitIdxMany :: Index key (NodeId height key val)
                  -> Index key (Node ('S height) key val)
checkSplitIdxMany idx
    | indexNumKeys idx <= maxIdxKeys
    = indexFromList [] [Idx idx]
    | (keys, idxs) <- splitIndexMany maxIdxKeys idx
    = indexFromList keys (map Idx idxs)

checkSplitLeafMany :: Key key => Map key val -> Index key (Node 'Z key val)
checkSplitLeafMany items
    | M.size items <= maxLeafItems
    = indexFromList [] [Leaf items]
    | (keys, leafs) <- splitLeafMany maxLeafItems items
    = indexFromList keys (map Leaf leafs)

--------------------------------------------------------------------------------

insertRec :: forall m height key val. (AllocM m, Key key, Value val)
    => key
    -> val
    -> Height height
    -> NodeId height key val
    -> m (Index key (NodeId height key val))
insertRec k v = fetch
  where
    fetch :: forall hgt.
           Height hgt
        -> NodeId hgt key val
        -> m (Index key (NodeId hgt key val))
    fetch hgt nid = do
        node <- readNode hgt nid
        freeNode hgt nid
        recurse hgt node

    recurse :: forall hgt.
           Height hgt
        -> Node hgt key val
        -> m (Index key (NodeId hgt key val))
    recurse hgt (Idx children) = do
        let (ctx,childId) = valView k children
        newChildIdx <- fetch (decrHeight hgt) childId
        traverse (allocNode hgt) (checkSplitIdx (putIdx ctx newChildIdx))
    recurse hgt (Leaf items) =
        traverse (allocNode hgt) (checkSplitLeaf (M.insert k v items))

insertRecMany :: forall m height key val. (AllocM m, Key key, Value val)
    => Height height
    -> Map key val
    -> NodeId height key val
    -> m (Index key (NodeId height key val))
insertRecMany h kvs nid = do
    n <- readNode h nid
    freeNode h nid
    case n of
        Idx idx -> do
            let dist = distribute kvs idx
            idx' <- dist `bindIndexM` uncurry (insertRecMany (decrHeight h))
            traverse (allocNode h) (checkSplitIdxMany idx')
        Leaf items ->
            traverse (allocNode h) (checkSplitLeafMany (M.union kvs items))


--------------------------------------------------------------------------------

insertTree :: (AllocM m, Key key, Value val)
    => key
    -> val
    -> Tree key val
    -> m (Tree key val)
insertTree key val tree
    | Tree
      { treeHeight = height
      , treeRootId = Just rootId
      } <- tree
    = do
          newRootIdx <- insertRec key val height rootId
          case fromSingletonIndex newRootIdx of
              Just newRootId ->
                  return $! Tree
                      { treeHeight = height
                      , treeRootId = Just newRootId
                      }
              Nothing -> do
                  -- Root got split, so allocate a new root node.
                  let newHeight = incrHeight height
                  newRootId <- allocNode newHeight Idx
                      { idxChildren = newRootIdx }
                  return $! Tree
                      { treeHeight = newHeight
                      , treeRootId = Just newRootId
                      }
    | Tree
      { treeRootId = Nothing
      } <- tree
    = do  -- Allocate new root node
          newRootId <- allocNode zeroHeight Leaf
              { leafItems = M.singleton key val
              }
          return $! Tree
              { treeHeight = zeroHeight
              , treeRootId = Just newRootId
              }

insertTreeMany :: (AllocM m, Key key, Value val)
    => Map key val
    -> Tree key val
    -> m (Tree key val)
insertTreeMany kvs tree
    | Tree
      { treeHeight = height
      , treeRootId = Just rootId
      } <- tree
    = do
        newRootIdx <- insertRecMany height kvs rootId
        fixUp height newRootIdx
    | Tree { treeRootId = Nothing } <- tree
    = do
        idx <- traverse (allocNode zeroHeight) (checkSplitLeafMany kvs)
        fixUp zeroHeight $! idx

{-| Fix up the root node of a tree.

    Fix up the root node of a tree, where all other nodes are valid, but the
    root node may contain more items than allowed. Do this by repeatedly
    splitting up the root node.
-}
fixUp :: (AllocM m, Key key, Value val)
       => Height height
       -> Index key (NodeId height key val)
       -> m (Tree key val)
fixUp h idx = case fromSingletonIndex idx of
    Just newRootNid ->
        return $! Tree { treeHeight = h
                       , treeRootId = Just newRootNid }
    Nothing -> do
        let newHeight = incrHeight h
        childrenNids <- traverse (allocNode newHeight) (checkSplitIdxMany idx)
        fixUp newHeight $! childrenNids

--------------------------------------------------------------------------------
