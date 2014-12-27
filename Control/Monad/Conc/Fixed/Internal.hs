{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE RankNTypes                #-}

-- | Concurrent monads with a fixed scheduler.
module Control.Monad.Conc.Fixed.Internal where

import Control.Applicative ((<$>))
import Control.Monad.Cont (Cont, runCont)
import Data.Map (Map)
import Data.Maybe (catMaybes, fromJust, isNothing)

import qualified Data.Map as M

-- | Doing this with a typeclass proved to be really hard, so here's a
-- dict of methods for different implementations to override!
--
-- Constraints: Functor (c t), Functor n, Monad (c t), Monad n.
data Fixed c n r t = F
  { newRef   :: forall a. a -> n (r a)
  -- ^ Create a new reference
  , readRef  :: forall a. r a -> n a
  -- ^ Read a reference.
  , writeRef :: forall a. r a -> a -> n ()
  -- ^ Overwrite the contents of a reference.
  , liftN    :: forall a. n a -> c t a
  -- ^ Lift an action from the underlying monad
  , unC      :: forall a. c t a -> M n r t a
  -- ^ Unpack the continuation-based computation from its wrapping
  -- type.
  }

-- | Scheduling is done in terms of a trace of 'Action's. Blocking can
-- only occur as a result of an action, and they cover (most of) the
-- primitives of the concurrency. `spawn` is absent as it can be
-- derived from `new`, `fork` and `put`.
data Action n r t =
    AFork (Action n r t) (Action n r t)
  | forall a. APut     (R r a) a (Action n r t)
  | forall a. ATryPut  (R r a) a (Bool -> Action n r t)
  | forall a. AGet     (R r a) (a -> Action n r t)
  | forall a. ATake    (R r a) (a -> Action n r t)
  | forall a. ATryTake (R r a) (Maybe a -> Action n r t)
  | ALift (n (Action n r t))
  | AStop

-- | Every thread has a unique identitifer. These are implemented as
-- integers, but you shouldn't assume they are necessarily contiguous.
type ThreadId = Int

-- | A @Scheduler@ maintains some internal state, `s`, takes the
-- 'ThreadId' of the last thread scheduled, and the list of runnable
-- threads (which will never be empty). It produces a 'ThreadId' to
-- schedule, and a new state.
--
-- Note: In order to prevent deadlock, the 'Conc' runtime will assume
-- that a deadlock situation has arisen if the scheduler attempts to
-- (a) schedule a blocked thread, or (b) schedule a nonexistant
-- thread. In either of those cases, the computation will be halted.
type Scheduler s = s -> ThreadId -> [ThreadId] -> (ThreadId, s)

-- | One of the outputs of the runner is a @Trace@, which is just a
-- log of threads and actions they have taken.
type Trace = [(ThreadId, ThreadAction)]

-- | All the actions that a thread can perform.
data ThreadAction =
    Fork ThreadId
  -- ^ Start a new thread.
  | Put [ThreadId]
  -- ^ Put into a 'CVar', possibly waking up some threads.
  | BlockedPut
  -- ^ Get blocked on a put.
  | TryPut Bool [ThreadId]
  -- ^ Try to put into a 'CVar', possibly waking up some threads.
  | Read
  -- ^ Read from a 'CVar'.
  | BlockedRead
  -- ^ Get blocked on a read.
  | Take [ThreadId]
  -- ^ Take from a 'CVar', possibly waking up some threads.
  | BlockedTake
  -- ^ Get blocked on a take.
  | TryTake Bool [ThreadId]
  -- ^ try to take from a 'CVar', possibly waking up some threads.
  | Lift
  -- ^ Lift an action from the underlying monad.
  deriving (Eq, Show)

-- | Run a concurrent computation with a given 'Scheduler' and initial
-- state, returning `Just result` if it terminates, and `Nothing` if a
-- deadlock is detected.
runFixed :: (Functor (c t), Functor n, Monad (c t), Monad n) => Fixed c n r t
         -> Scheduler s -> s -> c t a -> n (Maybe a)
runFixed fixed sched s ma = (\(a,_,_) -> a) <$> runFixed' fixed sched s ma

-- | Variant of 'runConc' which returns the final state of the
-- scheduler and an execution trace.
runFixed' :: (Functor (c t), Functor n, Monad (c t), Monad n) => Fixed c n r t
          -> Scheduler s -> s -> c t a -> n (Maybe a, s, Trace)
runFixed' fixed sched s ma = do
  ref <- newRef fixed Nothing
  let c  = unC fixed $ ma >>= liftN fixed . writeRef fixed ref . Just
  let threads = M.fromList [(0, (runCont c $ const AStop, False))]
  (s', trace) <- runThreads fixed [] (negate 1) sched s threads ref
  out <- readRef fixed ref
  return (out, s', reverse trace)

-- | A @Block@ is used to determine what sort of block a thread is
-- experiencing.
data Block = WaitFull ThreadId | WaitEmpty ThreadId deriving Eq

-- | Threads are represented as a tuple of (next action, is blocked).
type Threads n r t = Map ThreadId (Action n r t, Bool)

-- | The underlying monad is based on continuations over Actions.
type M n r t a = Cont (Action n r t) a

-- | CVars are represented as a reference containing a maybe value,
-- and a list of things blocked on it.
type R r a = r (Maybe a, [Block])

-- | Run a collection of threads, until there are no threads left.
--
-- A thread is represented as a tuple of (next action, is blocked).
--
-- Note: this returns the trace in reverse order, because it's more
-- efficient to prepend to a list than append. As this function isn't
-- exposed to users of the library, this is just an internal gotcha to
-- watch out for.
runThreads :: (Functor (c t), Functor n, Monad (c t), Monad n) => Fixed c n r t
           -> Trace -> ThreadId -> Scheduler s -> s -> Threads n r t -> r (Maybe a) -> n (s, Trace)
runThreads fixed sofar prior sched s threads ref
  | isTerminated  = return (s, sofar)
  | isDeadlocked  = writeRef fixed ref Nothing >> return (s, sofar)
  | isBlocked     = writeRef fixed ref Nothing >> return (s, sofar)
  | isNonexistant = writeRef fixed ref Nothing >> return (s, sofar)
  | otherwise = do
    (threads', act) <- stepThread (fst $ fromJust thread) fixed chosen threads
    let sofar' = maybe sofar (\a -> (chosen, a) : sofar) act
    runThreads fixed sofar' chosen sched s' threads' ref

  where
    (chosen, s')  = if prior == -1 then (0, s) else sched s prior $ M.keys runnable
    runnable      = M.filter (not . snd) threads
    thread        = M.lookup chosen threads
    isBlocked     = snd . fromJust $ M.lookup chosen threads
    isNonexistant = isNothing thread
    isTerminated  = 0 `notElem` M.keys threads
    isDeadlocked  = M.null runnable

-- | Run a single thread one step, by dispatching on the type of
-- 'Action'.
stepThread :: (Functor (c t), Functor n, Monad (c t), Monad n)
           => Action n r t
           -> Fixed c n r t -> ThreadId -> Threads n r t -> n (Threads n r t, Maybe ThreadAction)
stepThread (AFork    a b)     = stepFork    a b
stepThread (APut     ref a c) = stepPut     ref a c
stepThread (ATryPut  ref a c) = stepTryPut  ref a c
stepThread (AGet     ref c)   = stepGet     ref c
stepThread (ATake    ref c)   = stepTake    ref c
stepThread (ATryTake ref c)   = stepTryTake ref c
stepThread (ALift    na)      = stepLift    na
stepThread AStop             = stepStop

-- | Start a new thread, assigning it a unique 'ThreadId'
stepFork :: (Functor (c t), Functor n, Monad (c t), Monad n)
         => Action n r t -> Action n r t
         -> Fixed c n r t -> ThreadId -> Threads n r t -> n (Threads n r t, Maybe ThreadAction)
stepFork a b _ i threads =
  let (threads', newid) = launch a threads
  in return (goto b i threads', Just $ Fork newid)

-- | Put a value into a @CVar@, blocking the thread until it's empty.
stepPut :: (Functor (c t), Functor n, Monad (c t), Monad n)
        => R r a -> a -> Action n r t
        -> Fixed c n r t -> ThreadId -> Threads n r t -> n (Threads n r t, Maybe ThreadAction)
stepPut ref a c fixed i threads = do
  (val, blocks) <- readRef fixed ref
  case val of
    Just _  -> do
      threads' <- block fixed ref WaitEmpty i threads
      return (threads', Just BlockedPut)
    Nothing -> do
      writeRef fixed ref (Just a, blocks)
      (threads', woken) <- wake fixed ref WaitFull threads
      return (goto c i threads', Just $ Put woken)

-- | Try to put a value into a @CVar@, without blocking.
stepTryPut :: (Functor (c t), Functor n, Monad (c t), Monad n)
           => R r a -> a -> (Bool -> Action n r t)
           -> Fixed c n r t -> ThreadId -> Threads n r t -> n (Threads n r t, Maybe ThreadAction)
stepTryPut ref a c fixed i threads = do
  (val, blocks) <- readRef fixed ref
  case val of
    Just _  -> return (goto (c False) i threads, Just $ TryPut False [])
    Nothing -> do
      writeRef fixed ref (Just a, blocks)
      (threads', woken) <- wake fixed ref WaitFull threads
      return (goto (c True) i threads', Just $ TryPut True woken)

-- | Get the value from a @CVar@, without emptying, blocking the
-- thread until it's full.
stepGet :: (Functor (c t), Functor n, Monad (c t), Monad n)
        => R r a -> (a -> Action n r t)
        -> Fixed c n r t -> ThreadId -> Threads n r t -> n (Threads n r t, Maybe ThreadAction)
stepGet ref c fixed i threads = do
  (val, _) <- readRef fixed ref
  case val of
    Just val' -> return (goto (c val') i threads, Just Read)
    Nothing   -> do
      threads' <- block fixed ref WaitFull i threads
      return (threads', Just BlockedRead)

-- | Take the value from a @CVar@, blocking the thread until it's
-- full.
stepTake :: (Functor (c t), Functor n, Monad (c t), Monad n)
         => R r a -> (a -> Action n r t)
         -> Fixed c n r t -> ThreadId -> Threads n r t -> n (Threads n r t, Maybe ThreadAction)
stepTake ref c fixed i threads = do
  (val, blocks) <- readRef fixed ref
  case val of
    Just val' -> do
      writeRef fixed ref (Nothing, blocks)
      (threads', woken) <- wake fixed ref WaitEmpty threads
      return (goto (c val') i threads', Just $ Take woken)
    Nothing   -> do
      threads' <- block fixed ref WaitFull i threads
      return (threads', Just BlockedTake)

-- | Try to take the value from a @CVar@, without blocking.
stepTryTake :: (Functor (c t), Functor n, Monad (c t), Monad n)
            => R r a -> (Maybe a -> Action n r t)
            -> Fixed c n r t -> ThreadId -> Threads n r t -> n (Threads n r t, Maybe ThreadAction)
stepTryTake ref c fixed i threads = do
  (val, blocks) <- readRef fixed ref
  case val of
    Just _ -> do
      writeRef fixed ref (Nothing, blocks)
      (threads', woken) <- wake fixed ref WaitEmpty threads
      return (goto (c val) i threads', Just $ TryTake True woken)
    Nothing   -> return (goto (c Nothing) i threads, Just $ TryTake False [])

-- | Lift an action from the underlying monad into the @Conc@
-- computation.
stepLift :: (Functor (c t), Functor n, Monad (c t), Monad n)
         => n (Action n r t)
         -> Fixed c n r t -> ThreadId -> Threads n r t -> n (Threads n r t, Maybe ThreadAction)
stepLift na _ i threads = do
  a <- na
  return (goto a i threads, Just Lift)

-- | Kill the current thread.
stepStop :: (Functor (c t), Functor n, Monad (c t), Monad n)
         => Fixed c n r t -> ThreadId -> Threads n r t -> n (Threads n r t, Maybe ThreadAction)
stepStop _ i threads = return (kill i threads, Nothing)

-- | Replace the @Action@ of a thread.
goto :: Action n r t -> ThreadId -> Threads n r t -> Threads n r t
goto a = M.alter $ \(Just (_, b)) -> Just (a, b)

-- | Block a thread on a @CVar@.
block :: (Functor (c t), Functor n, Monad (c t), Monad n) => Fixed c n r t
      -> R r a -> (ThreadId -> Block) -> ThreadId -> Threads n r t -> n (Threads n r t)
block fixed ref typ tid threads = do
  (val, blocks) <- readRef fixed ref
  writeRef fixed ref (val, typ tid : blocks)
  return $ M.alter (\(Just (a, _)) -> Just (a, True)) tid threads

-- | Start a thread with the next free ID.
launch :: Action n r t -> Threads n r t -> (Threads n r t, ThreadId)
launch a m = (M.insert k (a, False) m, k) where
  k = succ . maximum $ M.keys m

-- | Kill a thread.
kill :: ThreadId -> Threads n r t -> Threads n r t
kill = M.delete

-- | Wake every thread blocked on a @CVar@ read/write.
wake :: (Functor (c t), Functor n, Monad (c t), Monad n) => Fixed c n r t
     -> R r a -> (ThreadId -> Block) -> Threads n r t -> n (Threads n r t, [ThreadId])
wake fixed ref typ m = do
  (m', woken) <- unzip <$> mapM wake' (M.toList m)

  return (M.fromList m', catMaybes woken)

  where
    wake' a@(tid, (act, True)) = do
      let blck = typ tid
      (val, blocks) <- readRef fixed ref

      if blck `elem` blocks
      then writeRef fixed ref (val, filter (/= blck) blocks) >> return ((tid, (act, False)), Just tid)
      else return (a, Nothing)

    wake' a = return (a, Nothing)
