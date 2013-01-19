-- Language extensions {{{
{-# LANGUAGE UnicodeSyntax #-}
-- }}}

module Control.Monad.Trans.Visitor.Utils.MonadStacks
    ( MonadStacks
    , emptyStacks
    , addToStacks
    , mergeStacks
    ) where

import Control.Monad (MonadPlus(..))
import Data.Word (Word)

data StackEntry α = StackEntry {-# UNPACK #-} !Word α
data MonadStacks α = EmptyStacks | MonadStacks {-# UNPACK #-} !Word α !(MonadStacks α)

emptyStacks :: MonadStacks α
emptyStacks = EmptyStacks
{-# INLINE emptyStacks #-}

addToStacks :: MonadPlus m ⇒ MonadStacks (m α) → m α → MonadStacks (m α)
addToStacks stacks x = go stacks (StackEntry 0 x)
  where
    go EmptyStacks entry@(StackEntry i x) = MonadStacks i x EmptyStacks
    go stacks@(MonadStacks i' x' rest) entry@(StackEntry i x)
     | i == i' = go rest (StackEntry (i+1) (x' `mplus` x))
     | otherwise = MonadStacks i x stacks
{-# INLINE addToStacks #-}

mergeStacks :: MonadPlus m ⇒ MonadStacks (m α) → m α
mergeStacks EmptyStacks = mzero
mergeStacks (MonadStacks _ x rest) = go rest x
  where
    go EmptyStacks x = x
    go (MonadStacks _ x' rest) x = go rest (x `mplus` x')
{-# INLINE mergeStacks #-}