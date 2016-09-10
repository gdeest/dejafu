-- |
-- Module      : Test.DejaFu.Common
-- Copyright   : (c) 2016 Michael Walker
-- License     : MIT
-- Maintainer  : Michael Walker <mike@barrucadu.co.uk>
-- Stability   : experimental
-- Portability : portable
--
-- Common types and functions used throughout DejaFu. This module is
-- NOT considered to form part of the public interface of this
-- library.
module Test.DejaFu.Common
  ( -- * Identifiers
    ThreadId(..)
  , CRefId(..)
  , MVarId(..)
  , TVarId(..)
  , initialThread
  -- ** Identifier source
  , IdSource(..)
  , nextCRId
  , nextMVId
  , nextTVId
  , nextTId
  , initialIdSource

  -- * Actions
  -- ** Thread actions
  , ThreadAction(..)
  , isBlock
  , tvarsOf
  -- ** Lookahead
  , Lookahead(..)
  , rewind
  , willRelease
  -- ** Simplified actions
  , ActionType(..)
  , isBarrier
  , isCommit
  , synchronises
  , crefOf
  , mvarOf
  , simplifyAction
  , simplifyLookahead
  -- ** STM actions
  , TTrace
  , TAction(..)

  -- * Traces
  , Trace
  , Decision(..)
  , showTrace
  , preEmpCount

  -- * Failures
  , Failure(..)
  , showFail

  -- * Memory models
  , MemType(..)
  ) where

import Control.DeepSeq (NFData(..))
import Control.Exception (MaskingState(..))
import Data.Dynamic (Dynamic)
import Data.List (sort, nub, intercalate)
import Data.Maybe (fromMaybe, mapMaybe)
import Data.Set (Set)
import qualified Data.Set as S
import Test.DPOR (Decision(..), Trace)

-------------------------------------------------------------------------------
-- Identifiers

-- | Every live thread has a unique identitifer.
data ThreadId = ThreadId (Maybe String) Int
  deriving Eq

instance Ord ThreadId where
  compare (ThreadId _ i) (ThreadId _ j) = compare i j

instance Show ThreadId where
  show (ThreadId (Just n) _) = n
  show (ThreadId Nothing  i) = show i

instance NFData ThreadId where
  rnf (ThreadId n i) = rnf (n, i)

-- | Every @CRef@ has a unique identifier.
data CRefId = CRefId (Maybe String) Int
  deriving Eq

instance Ord CRefId where
  compare (CRefId _ i) (CRefId _ j) = compare i j

instance Show CRefId where
  show (CRefId (Just n) _) = n
  show (CRefId Nothing  i) = show i

instance NFData CRefId where
  rnf (CRefId n i) = rnf (n, i)

-- | Every @MVar@ has a unique identifier.
data MVarId = MVarId (Maybe String) Int
  deriving Eq

instance Ord MVarId where
  compare (MVarId _ i) (MVarId _ j) = compare i j

instance Show MVarId where
  show (MVarId (Just n) _) = n
  show (MVarId Nothing  i) = show i

instance NFData MVarId where
  rnf (MVarId n i) = rnf (n, i)

-- | Every @TVar@ has a unique identifier.
data TVarId = TVarId (Maybe String) Int
  deriving Eq

instance Ord TVarId where
  compare (TVarId _ i) (TVarId _ j) = compare i j

instance Show TVarId where
  show (TVarId (Just n) _) = n
  show (TVarId Nothing  i) = show i

instance NFData TVarId where
  rnf (TVarId n i) = rnf (n, i)

-- | The ID of the initial thread.
initialThread :: ThreadId
initialThread = ThreadId (Just "main") 0

---------------------------------------
-- Identifier source

-- | The number of ID parameters was getting a bit unwieldy, so this
-- hides them all away.
data IdSource = Id
  { _nextCRId  :: Int
  , _nextMVId  :: Int
  , _nextTVId  :: Int
  , _nextTId   :: Int
  , _usedCRNames :: [String]
  , _usedMVNames :: [String]
  , _usedTVNames :: [String]
  , _usedTNames  :: [String]
  }

-- | Get the next free 'CRefId'.
nextCRId :: String -> IdSource -> (IdSource, CRefId)
nextCRId name idsource = (newIdSource, newCRId) where
  newIdSource = idsource { _nextCRId = newId, _usedCRNames = newUsed }
  newCRId     = CRefId newName newId
  newId       = _nextCRId idsource + 1
  (newName, newUsed) = nextId name (_usedCRNames idsource)

-- | Get the next free 'MVarId'.
nextMVId :: String -> IdSource -> (IdSource, MVarId)
nextMVId name idsource = (newIdSource, newMVId) where
  newIdSource = idsource { _nextMVId = newId, _usedMVNames = newUsed }
  newMVId     = MVarId newName newId
  newId       = _nextMVId idsource + 1
  (newName, newUsed) = nextId name (_usedMVNames idsource)

-- | Get the next free 'TVarId'.
nextTVId :: String -> IdSource -> (IdSource, TVarId)
nextTVId name idsource = (newIdSource, newTVId) where
  newIdSource = idsource { _nextTVId = newId, _usedTVNames = newUsed }
  newTVId     = TVarId newName newId
  newId       = _nextTVId idsource + 1
  (newName, newUsed) = nextId name (_usedTVNames idsource)

-- | Get the next free 'ThreadId'.
nextTId :: String -> IdSource -> (IdSource, ThreadId)
nextTId name idsource = (newIdSource, newTId) where
  newIdSource = idsource { _nextTId = newId, _usedTNames = newUsed }
  newTId      = ThreadId newName newId
  newId       = _nextTId idsource + 1
  (newName, newUsed) = nextId name (_usedTNames idsource)

-- | The initial ID source.
initialIdSource :: IdSource
initialIdSource = Id 0 0 0 0 [] [] [] []

-------------------------------------------------------------------------------
-- Actions

---------------------------------------
-- Thread actions

-- | All the actions that a thread can perform.
data ThreadAction =
    Fork ThreadId
  -- ^ Start a new thread.
  | MyThreadId
  -- ^ Get the 'ThreadId' of the current thread.
  | GetNumCapabilities Int
  -- ^ Get the number of Haskell threads that can run simultaneously.
  | SetNumCapabilities Int
  -- ^ Set the number of Haskell threads that can run simultaneously.
  | Yield
  -- ^ Yield the current thread.
  | NewVar MVarId
  -- ^ Create a new 'MVar'.
  | PutVar MVarId [ThreadId]
  -- ^ Put into a 'MVar', possibly waking up some threads.
  | BlockedPutVar MVarId
  -- ^ Get blocked on a put.
  | TryPutVar MVarId Bool [ThreadId]
  -- ^ Try to put into a 'MVar', possibly waking up some threads.
  | ReadVar MVarId
  -- ^ Read from a 'MVar'.
  | BlockedReadVar MVarId
  -- ^ Get blocked on a read.
  | TakeVar MVarId [ThreadId]
  -- ^ Take from a 'MVar', possibly waking up some threads.
  | BlockedTakeVar MVarId
  -- ^ Get blocked on a take.
  | TryTakeVar MVarId Bool [ThreadId]
  -- ^ Try to take from a 'MVar', possibly waking up some threads.
  | NewRef CRefId
  -- ^ Create a new 'CRef'.
  | ReadRef CRefId
  -- ^ Read from a 'CRef'.
  | ReadRefCas CRefId
  -- ^ Read from a 'CRef' for a future compare-and-swap.
  | ModRef CRefId
  -- ^ Modify a 'CRef'.
  | ModRefCas CRefId
  -- ^ Modify a 'CRef' using a compare-and-swap.
  | WriteRef CRefId
  -- ^ Write to a 'CRef' without synchronising.
  | CasRef CRefId Bool
  -- ^ Attempt to to a 'CRef' using a compare-and-swap, synchronising
  -- it.
  | CommitRef ThreadId CRefId
  -- ^ Commit the last write to the given 'CRef' by the given thread,
  -- so that all threads can see the updated value.
  | STM TTrace [ThreadId]
  -- ^ An STM transaction was executed, possibly waking up some
  -- threads.
  | BlockedSTM TTrace
  -- ^ Got blocked in an STM transaction.
  | Catching
  -- ^ Register a new exception handler
  | PopCatching
  -- ^ Pop the innermost exception handler from the stack.
  | Throw
  -- ^ Throw an exception.
  | ThrowTo ThreadId
  -- ^ Throw an exception to a thread.
  | BlockedThrowTo ThreadId
  -- ^ Get blocked on a 'throwTo'.
  | Killed
  -- ^ Killed by an uncaught exception.
  | SetMasking Bool MaskingState
  -- ^ Set the masking state. If 'True', this is being used to set the
  -- masking state to the original state in the argument passed to a
  -- 'mask'ed function.
  | ResetMasking Bool MaskingState
  -- ^ Return to an earlier masking state.  If 'True', this is being
  -- used to return to the state of the masked block in the argument
  -- passed to a 'mask'ed function.
  | LiftIO
  -- ^ Lift an IO action. Note that this can only happen with
  -- 'ConcIO'.
  | Return
  -- ^ A 'return' or 'pure' action was executed.
  | Message Dynamic
  -- ^ A '_concMessage' annotation was processed.
  | Stop
  -- ^ Cease execution and terminate.
  deriving Show

instance NFData ThreadAction where
  rnf (Fork t) = rnf t
  rnf (GetNumCapabilities i) = rnf i
  rnf (SetNumCapabilities i) = rnf i
  rnf (NewVar c) = rnf c
  rnf (PutVar c ts) = rnf (c, ts)
  rnf (BlockedPutVar c) = rnf c
  rnf (TryPutVar c b ts) = rnf (c, b, ts)
  rnf (ReadVar c) = rnf c
  rnf (BlockedReadVar c) = rnf c
  rnf (TakeVar c ts) = rnf (c, ts)
  rnf (BlockedTakeVar c) = rnf c
  rnf (TryTakeVar c b ts) = rnf (c, b, ts)
  rnf (NewRef c) = rnf c
  rnf (ReadRef c) = rnf c
  rnf (ReadRefCas c) = rnf c
  rnf (ModRef c) = rnf c
  rnf (ModRefCas c) = rnf c
  rnf (WriteRef c) = rnf c
  rnf (CasRef c b) = rnf (c, b)
  rnf (CommitRef t c) = rnf (t, c)
  rnf (STM s ts) = rnf (s, ts)
  rnf (BlockedSTM s) = rnf s
  rnf (ThrowTo t) = rnf t
  rnf (BlockedThrowTo t) = rnf t
  rnf (SetMasking b m) = b `seq` m `seq` ()
  rnf (ResetMasking b m) = b `seq` m `seq` ()
  rnf (Message m) = m `seq` ()
  rnf a = a `seq` ()

-- | Check if a @ThreadAction@ immediately blocks.
isBlock :: ThreadAction -> Bool
isBlock (BlockedThrowTo  _) = True
isBlock (BlockedTakeVar _) = True
isBlock (BlockedReadVar _) = True
isBlock (BlockedPutVar  _) = True
isBlock (BlockedSTM _) = True
isBlock _ = False

-- | Get the @TVar@s affected by a @ThreadAction@.
tvarsOf :: ThreadAction -> Set TVarId
tvarsOf act = S.fromList $ case act of
  STM trc _ -> concatMap tvarsOf' trc
  BlockedSTM trc -> concatMap tvarsOf' trc
  _ -> []

  where
    tvarsOf' (TRead  tv) = [tv]
    tvarsOf' (TWrite tv) = [tv]
    tvarsOf' (TOrElse ta tb) = concatMap tvarsOf' (ta ++ fromMaybe [] tb)
    tvarsOf' (TCatch  ta tb) = concatMap tvarsOf' (ta ++ fromMaybe [] tb)
    tvarsOf' _ = []

---------------------------------------
-- Lookahead

-- | A one-step look-ahead at what a thread will do next.
data Lookahead =
    WillFork
  -- ^ Will start a new thread.
  | WillMyThreadId
  -- ^ Will get the 'ThreadId'.
  | WillGetNumCapabilities
  -- ^ Will get the number of Haskell threads that can run
  -- simultaneously.
  | WillSetNumCapabilities Int
  -- ^ Will set the number of Haskell threads that can run
  -- simultaneously.
  | WillYield
  -- ^ Will yield the current thread.
  | WillNewVar
  -- ^ Will create a new 'MVar'.
  | WillPutVar MVarId
  -- ^ Will put into a 'MVar', possibly waking up some threads.
  | WillTryPutVar MVarId
  -- ^ Will try to put into a 'MVar', possibly waking up some threads.
  | WillReadVar MVarId
  -- ^ Will read from a 'MVar'.
  | WillTakeVar MVarId
  -- ^ Will take from a 'MVar', possibly waking up some threads.
  | WillTryTakeVar MVarId
  -- ^ Will try to take from a 'MVar', possibly waking up some threads.
  | WillNewRef
  -- ^ Will create a new 'CRef'.
  | WillReadRef CRefId
  -- ^ Will read from a 'CRef'.
  | WillReadRefCas CRefId
  -- ^ Will read from a 'CRef' for a future compare-and-swap.
  | WillModRef CRefId
  -- ^ Will modify a 'CRef'.
  | WillModRefCas CRefId
  -- ^ Will nodify a 'CRef' using a compare-and-swap.
  | WillWriteRef CRefId
  -- ^ Will write to a 'CRef' without synchronising.
  | WillCasRef CRefId
  -- ^ Will attempt to to a 'CRef' using a compare-and-swap,
  -- synchronising it.
  | WillCommitRef ThreadId CRefId
  -- ^ Will commit the last write by the given thread to the 'CRef'.
  | WillSTM
  -- ^ Will execute an STM transaction, possibly waking up some
  -- threads.
  | WillCatching
  -- ^ Will register a new exception handler
  | WillPopCatching
  -- ^ Will pop the innermost exception handler from the stack.
  | WillThrow
  -- ^ Will throw an exception.
  | WillThrowTo ThreadId
  -- ^ Will throw an exception to a thread.
  | WillSetMasking Bool MaskingState
  -- ^ Will set the masking state. If 'True', this is being used to
  -- set the masking state to the original state in the argument
  -- passed to a 'mask'ed function.
  | WillResetMasking Bool MaskingState
  -- ^ Will return to an earlier masking state.  If 'True', this is
  -- being used to return to the state of the masked block in the
  -- argument passed to a 'mask'ed function.
  | WillLiftIO
  -- ^ Will lift an IO action. Note that this can only happen with
  -- 'ConcIO'.
  | WillReturn
  -- ^ Will execute a 'return' or 'pure' action.
  | WillMessage Dynamic
  -- ^ Will process a _concMessage' annotation.
  | WillStop
  -- ^ Will cease execution and terminate.
  deriving Show

instance NFData Lookahead where
  rnf (WillSetNumCapabilities i) = rnf i
  rnf (WillPutVar c) = rnf c
  rnf (WillTryPutVar c) = rnf c
  rnf (WillReadVar c) = rnf c
  rnf (WillTakeVar c) = rnf c
  rnf (WillTryTakeVar c) = rnf c
  rnf (WillReadRef c) = rnf c
  rnf (WillReadRefCas c) = rnf c
  rnf (WillModRef c) = rnf c
  rnf (WillModRefCas c) = rnf c
  rnf (WillWriteRef c) = rnf c
  rnf (WillCasRef c) = rnf c
  rnf (WillCommitRef t c) = rnf (t, c)
  rnf (WillThrowTo t) = rnf t
  rnf (WillSetMasking b m) = b `seq` m `seq` ()
  rnf (WillResetMasking b m) = b `seq` m `seq` ()
  rnf (WillMessage m) = m `seq` ()
  rnf l = l `seq` ()

-- | Convert a 'ThreadAction' into a 'Lookahead': \"rewind\" what has
-- happened. 'Killed' has no 'Lookahead' counterpart.
rewind :: ThreadAction -> Maybe Lookahead
rewind (Fork _) = Just WillFork
rewind MyThreadId = Just WillMyThreadId
rewind (GetNumCapabilities _) = Just WillGetNumCapabilities
rewind (SetNumCapabilities i) = Just (WillSetNumCapabilities i)
rewind Yield = Just WillYield
rewind (NewVar _) = Just WillNewVar
rewind (PutVar c _) = Just (WillPutVar c)
rewind (BlockedPutVar c) = Just (WillPutVar c)
rewind (TryPutVar c _ _) = Just (WillTryPutVar c)
rewind (ReadVar c) = Just (WillReadVar c)
rewind (BlockedReadVar c) = Just (WillReadVar c)
rewind (TakeVar c _) = Just (WillTakeVar c)
rewind (BlockedTakeVar c) = Just (WillTakeVar c)
rewind (TryTakeVar c _ _) = Just (WillTryTakeVar c)
rewind (NewRef _) = Just WillNewRef
rewind (ReadRef c) = Just (WillReadRef c)
rewind (ReadRefCas c) = Just (WillReadRefCas c)
rewind (ModRef c) = Just (WillModRef c)
rewind (ModRefCas c) = Just (WillModRefCas c)
rewind (WriteRef c) = Just (WillWriteRef c)
rewind (CasRef c _) = Just (WillCasRef c)
rewind (CommitRef t c) = Just (WillCommitRef t c)
rewind (STM _ _) = Just WillSTM
rewind (BlockedSTM _) = Just WillSTM
rewind Catching = Just WillCatching
rewind PopCatching = Just WillPopCatching
rewind Throw = Just WillThrow
rewind (ThrowTo t) = Just (WillThrowTo t)
rewind (BlockedThrowTo t) = Just (WillThrowTo t)
rewind Killed = Nothing
rewind (SetMasking b m) = Just (WillSetMasking b m)
rewind (ResetMasking b m) = Just (WillResetMasking b m)
rewind LiftIO = Just WillLiftIO
rewind Return = Just WillReturn
rewind (Message m) = Just (WillMessage m)
rewind Stop = Just WillStop

-- | Check if an operation could enable another thread.
willRelease :: Lookahead -> Bool
willRelease WillFork = True
willRelease WillYield = True
willRelease (WillPutVar _) = True
willRelease (WillTryPutVar _) = True
willRelease (WillReadVar _) = True
willRelease (WillTakeVar _) = True
willRelease (WillTryTakeVar _) = True
willRelease WillSTM = True
willRelease WillThrow = True
willRelease (WillSetMasking _ _) = True
willRelease (WillResetMasking _ _) = True
willRelease WillStop = True
willRelease _ = False

---------------------------------------
-- Simplified actions

-- | A simplified view of the possible actions a thread can perform.
data ActionType =
    UnsynchronisedRead  CRefId
  -- ^ A 'readCRef' or a 'readForCAS'.
  | UnsynchronisedWrite CRefId
  -- ^ A 'writeCRef'.
  | UnsynchronisedOther
  -- ^ Some other action which doesn't require cross-thread
  -- communication.
  | PartiallySynchronisedCommit CRefId
  -- ^ A commit.
  | PartiallySynchronisedWrite  CRefId
  -- ^ A 'casCRef'
  | PartiallySynchronisedModify CRefId
  -- ^ A 'modifyCRefCAS'
  | SynchronisedModify  CRefId
  -- ^ An 'atomicModifyCRef'.
  | SynchronisedRead    MVarId
  -- ^ A 'readMVar' or 'takeMVar' (or @try@/@blocked@ variants).
  | SynchronisedWrite   MVarId
  -- ^ A 'putMVar' (or @try@/@blocked@ variant).
  | SynchronisedOther
  -- ^ Some other action which does require cross-thread
  -- communication.
  deriving (Eq, Show)

instance NFData ActionType where
  rnf (UnsynchronisedRead  r) = rnf r
  rnf (UnsynchronisedWrite r) = rnf r
  rnf (PartiallySynchronisedCommit r) = rnf r
  rnf (PartiallySynchronisedWrite  r) = rnf r
  rnf (PartiallySynchronisedModify  r) = rnf r
  rnf (SynchronisedModify  r) = rnf r
  rnf (SynchronisedRead    c) = rnf c
  rnf (SynchronisedWrite   c) = rnf c
  rnf a = a `seq` ()

-- | Check if an action imposes a write barrier.
isBarrier :: ActionType -> Bool
isBarrier (SynchronisedModify _) = True
isBarrier (SynchronisedRead   _) = True
isBarrier (SynchronisedWrite  _) = True
isBarrier SynchronisedOther = True
isBarrier _ = False

-- | Check if an action commits a given 'CRef'.
isCommit :: ActionType -> CRefId -> Bool
isCommit (PartiallySynchronisedCommit c) r = c == r
isCommit (PartiallySynchronisedWrite  c) r = c == r
isCommit (PartiallySynchronisedModify c) r = c == r
isCommit _ _ = False

-- | Check if an action synchronises a given 'CRef'.
synchronises :: ActionType -> CRefId -> Bool
synchronises a r = isCommit a r || isBarrier a

-- | Get the 'CRef' affected.
crefOf :: ActionType -> Maybe CRefId
crefOf (UnsynchronisedRead  r) = Just r
crefOf (UnsynchronisedWrite r) = Just r
crefOf (SynchronisedModify  r) = Just r
crefOf (PartiallySynchronisedCommit r) = Just r
crefOf (PartiallySynchronisedWrite  r) = Just r
crefOf (PartiallySynchronisedModify r) = Just r
crefOf _ = Nothing

-- | Get the 'MVar' affected.
mvarOf :: ActionType -> Maybe MVarId
mvarOf (SynchronisedRead  c) = Just c
mvarOf (SynchronisedWrite c) = Just c
mvarOf _ = Nothing

-- | Throw away information from a 'ThreadAction' and give a
-- simplified view of what is happening.
--
-- This is used in the SCT code to help determine interesting
-- alternative scheduling decisions.
simplifyAction :: ThreadAction -> ActionType
simplifyAction = maybe UnsynchronisedOther simplifyLookahead . rewind

-- | Variant of 'simplifyAction' that takes a 'Lookahead'.
simplifyLookahead :: Lookahead -> ActionType
simplifyLookahead (WillPutVar c)     = SynchronisedWrite c
simplifyLookahead (WillTryPutVar c)  = SynchronisedWrite c
simplifyLookahead (WillReadVar c)    = SynchronisedRead c
simplifyLookahead (WillTakeVar c)    = SynchronisedRead c
simplifyLookahead (WillTryTakeVar c) = SynchronisedRead c
simplifyLookahead (WillReadRef r)     = UnsynchronisedRead r
simplifyLookahead (WillReadRefCas r)  = UnsynchronisedRead r
simplifyLookahead (WillModRef r)      = SynchronisedModify r
simplifyLookahead (WillModRefCas r)   = PartiallySynchronisedModify r
simplifyLookahead (WillWriteRef r)    = UnsynchronisedWrite r
simplifyLookahead (WillCasRef r)      = PartiallySynchronisedWrite r
simplifyLookahead (WillCommitRef _ r) = PartiallySynchronisedCommit r
simplifyLookahead WillSTM         = SynchronisedOther
simplifyLookahead (WillThrowTo _) = SynchronisedOther
simplifyLookahead _ = UnsynchronisedOther

---------------------------------------
-- STM actions

-- | A trace of an STM transaction is just a list of actions that
-- occurred, as there are no scheduling decisions to make.
type TTrace = [TAction]

-- | All the actions that an STM transaction can perform.
data TAction =
    TNew
  -- ^ Create a new @TVar@
  | TRead  TVarId
  -- ^ Read from a @TVar@.
  | TWrite TVarId
  -- ^ Write to a @TVar@.
  | TRetry
  -- ^ Abort and discard effects.
  | TOrElse TTrace (Maybe TTrace)
  -- ^ Execute a transaction until it succeeds (@STMStop@) or aborts
  -- (@STMRetry@) and, if it aborts, execute the other transaction.
  | TThrow
  -- ^ Throw an exception, abort, and discard effects.
  | TCatch TTrace (Maybe TTrace)
  -- ^ Execute a transaction until it succeeds (@STMStop@) or aborts
  -- (@STMThrow@). If the exception is of the appropriate type, it is
  -- handled and execution continues; otherwise aborts, propagating
  -- the exception upwards.
  | TStop
  -- ^ Terminate successfully and commit effects.
  deriving (Eq, Show)

instance NFData TAction where
  rnf (TRead  v) = rnf v
  rnf (TWrite v) = rnf v
  rnf (TCatch  s m) = rnf (s, m)
  rnf (TOrElse s m) = rnf (s, m)
  rnf a = a `seq` ()

-------------------------------------------------------------------------------
-- Traces

-- | Pretty-print a trace, including a key of the thread IDs (not
-- including thread 0). Each line of the key is indented by two
-- spaces.
showTrace :: Trace ThreadId ThreadAction Lookahead -> String
showTrace trc = intercalate "\n" $ concatMap go trc : strkey where
  go (_,_,CommitRef _ _) = "C-"
  go (Start    (ThreadId _ i),_,_) = "S" ++ show i ++ "-"
  go (SwitchTo (ThreadId _ i),_,_) = "P" ++ show i ++ "-"
  go (Continue,_,_) = "-"

  strkey = ["  " ++ show i ++ ": " ++ name | (i, name) <- key]

  key = sort . nub $ mapMaybe toKey trc where
    toKey (Start (ThreadId (Just name) i), _, _)
      | i > 0 = Just (i, name)
    toKey _ = Nothing

-- | Count the number of pre-emptions in a schedule prefix.
--
-- Commit threads complicate this a bit. Conceptually, commits are
-- happening truly in parallel, nondeterministically. The commit
-- thread implementation is just there to unify the two sources of
-- nondeterminism: commit timing and thread scheduling.
--
-- SO, we don't count a switch TO a commit thread as a
-- preemption. HOWEVER, the switch FROM a commit thread counts as a
-- preemption if it is not to the thread that the commit interrupted.
preEmpCount :: [(Decision ThreadId, ThreadAction)]
            -> (Decision ThreadId, Lookahead)
            -> Int
preEmpCount ts (d, _) = go initialThread Nothing ts where
  go _ (Just Yield) ((SwitchTo t, a):rest) = go t (Just a) rest
  go tid prior ((SwitchTo t, a):rest)
    | isCommitThread t = go tid prior (skip rest)
    | otherwise = 1 + go t (Just a) rest
  go _   _ ((Start t,  a):rest) = go t   (Just a) rest
  go tid _ ((Continue, a):rest) = go tid (Just a) rest
  go _ prior [] = case (prior, d) of
    (Just Yield, SwitchTo _) -> 0
    (_, SwitchTo _) -> 1
    _ -> 0

  -- Commit threads have negative thread IDs for easy identification.
  isCommitThread = (< initialThread)

  -- Skip until the next context switch.
  skip = dropWhile (not . isContextSwitch . fst)
  isContextSwitch Continue = False
  isContextSwitch _ = True

-------------------------------------------------------------------------------
-- Failures


-- | An indication of how a concurrent computation failed.
data Failure =
    InternalError
  -- ^ Will be raised if the scheduler does something bad. This should
  -- never arise unless you write your own, faulty, scheduler! If it
  -- does, please file a bug report.
  | Abort
  -- ^ The scheduler chose to abort execution. This will be produced
  -- if, for example, all possible decisions exceed the specified
  -- bounds (there have been too many pre-emptions, the computation
  -- has executed for too long, or there have been too many yields).
  | Deadlock
  -- ^ The computation became blocked indefinitely on @MVar@s.
  | STMDeadlock
  -- ^ The computation became blocked indefinitely on @TVar@s.
  | UncaughtException
  -- ^ An uncaught exception bubbled to the top of the computation.
  deriving (Eq, Show, Read, Ord, Enum, Bounded)

instance NFData Failure where
  rnf f = f `seq` ()

-- | Pretty-print a failure
showFail :: Failure -> String
showFail Abort             = "[abort]"
showFail Deadlock          = "[deadlock]"
showFail STMDeadlock       = "[stm-deadlock]"
showFail InternalError     = "[internal-error]"
showFail UncaughtException = "[exception]"

-------------------------------------------------------------------------------
-- Memory Models

-- | The memory model to use for non-synchronised 'CRef' operations.
data MemType =
    SequentialConsistency
  -- ^ The most intuitive model: a program behaves as a simple
  -- interleaving of the actions in different threads. When a 'CRef'
  -- is written to, that write is immediately visible to all threads.
  | TotalStoreOrder
  -- ^ Each thread has a write buffer. A thread sees its writes
  -- immediately, but other threads will only see writes when they are
  -- committed, which may happen later. Writes are committed in the
  -- same order that they are created.
  | PartialStoreOrder
  -- ^ Each 'CRef' has a write buffer. A thread sees its writes
  -- immediately, but other threads will only see writes when they are
  -- committed, which may happen later. Writes to different 'CRef's
  -- are not necessarily committed in the same order that they are
  -- created.
  deriving (Eq, Show, Read, Ord, Enum, Bounded)

instance NFData MemType where
  rnf m = m `seq` ()

-------------------------------------------------------------------------------
-- Utilities

-- | Helper for @next*@
nextId :: String -> [String] -> (Maybe String, [String])
nextId name used = (newName, newUsed) where
  newName
    | null name = Nothing
    | occurrences > 0 = Just (name ++ "-" ++ show occurrences)
    | otherwise = Just name
  newUsed
    | null name = used
    | otherwise = name : used
  occurrences = length (filter (==name) used)