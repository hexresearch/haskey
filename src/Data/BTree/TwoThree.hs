
module Data.BTree.TwoThree where

-- Setup of a 2-3 tree.
minFanout :: Int
minFanout = 2

maxFanout :: Int
maxFanout = 2*minFanout-1

minIdxKeys :: Int
minIdxKeys = minFanout - 1

maxIdxKeys :: Int
maxIdxKeys = maxFanout - 1

minLeafItems :: Int
minLeafItems = minFanout

maxLeafItems :: Int
maxLeafItems = 2*minFanout-1