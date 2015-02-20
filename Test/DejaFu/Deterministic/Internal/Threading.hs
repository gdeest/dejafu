{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE RankNTypes                #-}

-- | Operations and types for threads.
module Test.DejaFu.Deterministic.Internal.Threading where

import Control.Applicative ((<$>))
import Control.Exception (Exception, MaskingState(..), SomeException(..), fromException)
import Control.Monad.Cont (cont)
import Data.List (intersect)
import Data.Map (Map)
import Data.Maybe (fromMaybe, isJust)
import Test.DejaFu.STM (CTVarId)
import Test.DejaFu.Deterministic.Internal.Common

import qualified Data.Map as M

--------------------------------------------------------------------------------
-- * Threads

-- | Threads are stored in a map index by 'ThreadId'.
type Threads n r s = Map ThreadId (Thread n r s)

-- | All the state of a thread.
data Thread n r s = Thread
  { _continuation :: Action n r s
  -- ^ The next action to execute.
  , _blocking     :: Maybe BlockedOn
  -- ^ The state of any blocks.
  , _handlers     :: [Handler n r s]
  -- ^ Stack of exception handlers
  , _masking      :: MaskingState
  -- ^ The exception masking state.
  }

--------------------------------------------------------------------------------
-- * Blocking

-- | A @BlockedOn@ is used to determine what sort of variable a thread
-- is blocked on.
data BlockedOn = OnCVarFull CVarId | OnCVarEmpty CVarId | OnCTVar [CTVarId] | OnMask ThreadId deriving Eq

-- | Determine if a thread is blocked in a certainw ay.
(~=) :: Thread n r s -> BlockedOn -> Bool
thread ~= theblock = case (_blocking thread, theblock) of
  (Just (OnCVarFull  _), OnCVarFull  _) -> True
  (Just (OnCVarEmpty _), OnCVarEmpty _) -> True
  (Just (OnCTVar     _), OnCTVar     _) -> True
  (Just (OnMask      _), OnMask      _) -> True
  _ -> False

--------------------------------------------------------------------------------
-- * Exceptions

-- | An exception handler.
data Handler n r s = forall e. Exception e => Handler (e -> Action n r s)

-- | Propagate an exception upwards, finding the closest handler
-- which can deal with it.
propagate :: SomeException -> [Handler n r s] -> Maybe (Action n r s, [Handler n r s])
propagate _ [] = Nothing
propagate e (Handler h:hs) = maybe (propagate e hs) (\act -> Just (act, hs)) $ h <$> e' where
  e' = fromException e

-- | Check if a thread can be interrupted by an exception.
interruptible :: Thread n r s -> Bool
interruptible thread = _masking thread == Unmasked || (_masking thread == MaskedInterruptible && isJust (_blocking thread))

--------------------------------------------------------------------------------
-- * Manipulating threads

-- | Replace the @Action@ of a thread.
goto :: Action n r s -> ThreadId -> Threads n r s -> Threads n r s
goto a = M.alter $ \(Just thread) -> Just (thread { _continuation = a })

-- | Start a thread with the given ID, inheriting the masking state
-- from the parent thread. This must not already be in use!
launch :: ThreadId -> ThreadId -> ((forall b. M n r s b -> M n r s b) -> Action n r s) -> Threads n r s -> Threads n r s
launch parent tid a threads = launch' mask tid a threads where
  mask = fromMaybe Unmasked $ _masking <$> M.lookup parent threads

-- | Start a thread with the given ID and masking state. This must not already be in use!
launch' :: MaskingState -> ThreadId -> ((forall b. M n r s b -> M n r s b) -> Action n r s) -> Threads n r s -> Threads n r s
launch' mask tid a = M.insert tid thread where
  thread = Thread { _continuation = a umask, _blocking = Nothing, _handlers = [], _masking = mask }

  umask mb = resetMask True Unmasked >> mb >>= \b -> resetMask False mask >> return b
  resetMask typ m = cont $ \k -> AResetMask typ True m $ k ()

-- | Kill a thread.
kill :: ThreadId -> Threads n r s -> Threads n r s
kill = M.delete

-- | Block a thread.
block :: BlockedOn -> ThreadId -> Threads n r s -> Threads n r s
block blockedOn = M.alter doBlock where
  doBlock (Just thread) = Just $ thread { _blocking = Just blockedOn }

-- | Unblock all threads waiting on the appropriate block. For 'CTVar'
-- blocks, this will wake all threads waiting on at least one of the
-- given 'CTVar's.
wake :: BlockedOn -> Threads n r s -> (Threads n r s, [ThreadId])
wake blockedOn threads = (M.map unblock threads, M.keys $ M.filter isBlocked threads) where
  unblock thread
    | isBlocked thread = thread { _blocking = Nothing }
    | otherwise = thread

  isBlocked thread = case (_blocking thread, blockedOn) of
    (Just (OnCTVar ctvids), OnCTVar blockedOn') -> ctvids `intersect` blockedOn' /= []
    (theblock, _) -> theblock == Just blockedOn