Release Notes
=============

All notable changes to this project will be documented in this file.

This project is versioned according to the [Package Versioning Policy](https://pvp.haskell.org), the
*de facto* standard Haskell versioning scheme.


unreleased
----------

### Miscellaneous

- There is now a changelog.


---------------------------------------------------------------------------------------------------


0.5.1.3 [2017-04-05] (git tag: [dejafu-0.5.1.3][])
-------

https://hackage.haskell.org/package/dejafu-0.5.1.3

### Miscellaneous

- The version range on the concurrency package has been changed to 1.1.*.

[dejafu-0.5.1.3]: https://github.com/barrucadu/dejafu/releases/tag/dejafu-0.5.1.3


---------------------------------------------------------------------------------------------------


0.5.1.2 [2017-03-04] (git tag: [dejafu-0.5.1.2][])
-------

https://hackage.haskell.org/package/dejafu-0.5.1.2

### Test.DejaFu.Conc

- New `MonadRef` and `MonadAtomicRef` instances for the `Conc` type using `CRef`.

### Fixed

- A long-standing bug where if the main thread is killed with a `throwTo`, the throwing neither
  appears in the trace nor correctly terminates the execution.

### Miscellaneous

- The maximum supported version of the concurrency package has been changed to 1.1.1.*.

[dejafu-0.5.1.2]: https://github.com/barrucadu/dejafu/releases/tag/dejafu-0.5.1.2


---------------------------------------------------------------------------------------------------


0.5.1.1 [2017-02-25] (git tag: [dejafu-0.5.1.1][])
-------

https://hackage.haskell.org/package/dejafu-0.5.1.1

### Fixed

- The correct scheduler state is now passed to the scheduler immediately after the termination of a
  `subconcurrency` action.
- SCT of subconcurrency no longer loops infinitely.

[dejafu-0.5.1.1]: https://github.com/barrucadu/dejafu/releases/tag/dejafu-0.5.1.1


---------------------------------------------------------------------------------------------------


0.5.1.0 [2017-02-25] (git tag: [dejafu-0.5.1.0][])
-------

https://hackage.haskell.org/package/dejafu-0.5.1.0

### Test.DejaFu

- A new `NFData` instance for `Result`.

### Test.DejaFu.Common

- New instances:
    - `NFData` for `ThreadId`, `CRefId`, `MVarId`, `TVarId`, `IdSource`, `ThreadAction`,
      `Lookahead`, `ActionType`, `TAction`, `Decision`, `Failure`, and `MemType`.
    - `Eq`, `Ord`, and `Show` instances for `IdSource`.

### Test.DejaFu.SCT

- New `NFData` instances for `Way`, `Bounds`, `PreemptionBound`, `FairBound`, and `LengthBound`.
- New strict variants of `runSCT` and `resultsSet`: `runSCT'` and `resultsSet'`.

### Test.DejaFu.STM

- A new `NFData` instance for `Result`.

[dejafu-0.5.1.0]: https://github.com/barrucadu/dejafu/releases/tag/dejafu-0.5.1.0


---------------------------------------------------------------------------------------------------


0.5.0.2 [2017-02-22] (git tag: [dejafu-0.5.0.2][])
-------

https://hackage.haskell.org/package/dejafu-0.5.0.2

**This version was misnumbered! It should have caused a major version bump!**

### Test.DejaFu.Common

- A new `StopSubconcurrency` constructor of `ThreadAction`.

### Changed

- A `StopConcurrency` action appears in the execution trace immediately after the end of a
  `subconcurrency` action (much like the `PopCatching` and `ResetMasking` actions which appear after
  a catch and mask).
- A `subconcurrency` action now inherits the number of capabilities from the outer computation,
  rather than being reset to 2 as before.

### Miscellaneous

- Test.DejaFu.SCT now compiles with MonoLocalBinds enabled (implied by GADTs and TypeFamilies),
  which may be relevant to hackers.

[dejafu-0.5.0.2]: https://github.com/barrucadu/dejafu/releases/tag/dejafu-0.5.0.2


---------------------------------------------------------------------------------------------------


0.5.0.1 [2017-02-21] (git tag: [dejafu-0.5.0.1][])
-------

**This version was never pushed to hackage, whoops!**

### Fixed

- `readMVar` is once again considered a "release action" for the purposes of fair-bounding.

[dejafu-0.5.0.1]: https://github.com/barrucadu/dejafu/releases/tag/dejafu-0.5.0.1


---------------------------------------------------------------------------------------------------


0.5.0.0 [2017-02-21] (git tag: [dejafu-0.5.0.0][])
-------

https://hackage.haskell.org/package/dejafu-0.5.0.0

### Test.DejaFu

- All the functions which did take a `Bounds` now take a `Way` instead and support random scheduling
  as well.

### Test.DejaFu.Common

- New `Eq` instances for `ThreadAction` and `Lookahead`.
- A `TryReadMVar` constructor for `ThreadAction` and a corresponding `WillTryReadMVar` constructor
  for `Lookahead`.

### Test.DejaFu.Conc

- A new testing-only `subconcurrency` function, to run a concurrent action and do something with its
  result in the same concurrent context, even if it fails.

### Test.DejaFu.SCT

- An `sctRandom` function to run a fixed number of randomly-scheduled executions of a program.
- The `Way` type, to abstract over how to run a concurrent program, used by new functions `runSCT`
  and `resultsSet`.

### Fixed

- Some previously-missed `CRef` action dependencies are no longer missed.

### Miscellaneous

- The supported version of the concurrency package was bumped to 1.1.0.0, introducing `tryReadMVar`.
- A bunch of things were called "Var" or "Ref", these are now consistently "MVar" and "CRef".
- Significant performance improvements in both time and space.
- The dpor package has been merged back into this, as it turned out not to be very generally
  useful. There is no direct replacement, but I have no intent to update it, so the dpor package is
  now __deprecated__.

[dejafu-0.5.0.0]: https://github.com/barrucadu/dejafu/releases/tag/dejafu-0.5.0.0


---------------------------------------------------------------------------------------------------


0.4.0.0 [2016-09-10] (git tag: [dejafu-0.4.0.0][])
-------

https://hackage.haskell.org/package/dejafu-0.4.0.0

### Test.DejaFu

- The `autocheck'` function now takes the schedule bounds as a parameter.
- New `runTestM` and `runTestM'` functions, monad-polymorphic variants of the now-removed
  `runTestIO` and `runTestIO'` functions.

### Test.DejaFu.Conc

- The `Conc` type no longer has the STM type as a parameter.
- A new `runConcurrent` function, a monad-polymorphic version of the now-removed `runConcST` and
  `runConcIO` functions.

### Test.DejaFu.SCT

- The `ST`-specific functions are now monad-polymorphic.
- The `IO` function variants have been removed.

### Test.DejaFu.STM

- A new `runTransaction` function, a monad-polymorphic version of the now-removed `runTransactionST`
  and `runTransactionIO` functions.

### Changed

- The termination of the main thread in execution traces now appears as a single `Stop`, rather than
  the sequence `Lift, Stop`.
- Execution traces printed by the helpful functions in Test.DejaFu now include a key of thread
  names.

### Miscellaneous

- Remodularisation:
    - The Control.* modules have all been split out into a separate "concurrency" package.
    - Many definitions from other modules have been moved to the new Test.DejaFu.Common module.
    - The Test.DejaFu.Deterministic module has been renamed to Test.DejaFu.Conc

[dejafu-0.4.0.0]: https://github.com/barrucadu/dejafu/releases/tag/dejafu-0.4.0.0


---------------------------------------------------------------------------------------------------


0.3.2.1 [2016-07-21] (git tag: [dejafu-0.3.2.1][])
-------

https://hackage.haskell.org/package/dejafu-0.3.2.1

### Fixed

- The implementation of the STM `orElse` for `STMLike` incorrectly handled some state
  non-associatively, leading to false deadlocks being reported in some cases.

[dejafu-0.3.2.1]: https://github.com/barrucadu/dejafu/releases/tag/dejafu-0.3.2.1


---------------------------------------------------------------------------------------------------


0.3.2.0 [2016-06-06] (git tag: [dejafu-0.3.2.0][])
-------

https://hackage.haskell.org/package/dejafu-0.3.2.0

**Builds with both dpor-0.1 and dpor-0.2, however some improvements require dpor-0.2.**

### Fixed

- (faster with dpor-0.2) Executions missed due to daemon threads with uninteresting first actions
  are no longer missed.

### Changed

- (requires dpor-0.2) Significantly improved dependency inference of exceptions, greatly improving
  performance of testcases using exceptions.
- Significantly improved dependency inference of STM transactions, greatly improving performance of
  testcases using STM.

[dejafu-0.3.2.0]: https://github.com/barrucadu/dejafu/releases/tag/dejafu-0.3.2.0


---------------------------------------------------------------------------------------------------


0.3.1.1 [2016-05-26] (git tag: [dejafu-0.3.1.1][])
-------

https://hackage.haskell.org/package/dejafu-0.3.1.1

### Miscellaneous

- Now supports GHC 8.

[dejafu-0.3.1.1]: https://github.com/barrucadu/dejafu/releases/tag/dejafu-0.3.1.1


---------------------------------------------------------------------------------------------------


0.3.1.0 [2016-05-02] (git tag: [dejafu-0.3.1.0][])
-------

https://hackage.haskell.org/package/dejafu-0.3.1.0

### Fixed

- Context switches around relaxed memory commit actions could cause the number of pre-emptions in an
  execution to be miscounted, leading to the pre-emption bounding being too lenient.

[dejafu-0.3.1.0]: https://github.com/barrucadu/dejafu/releases/tag/dejafu-0.3.1.0


---------------------------------------------------------------------------------------------------


0.3.0.0 [2016-04-03] (git tag: [dejafu-0.3.0.0][])
-------

https://hackage.haskell.org/package/dejafu-0.3.0.0

**The minimum supported version of GHC is now 7.10.**

I didn't write proper release notes, and this is so far back I don't really care to dig through the
logs.

[dejafu-0.3.0.0]: https://github.com/barrucadu/dejafu/releases/tag/dejafu-0.3.0.0


---------------------------------------------------------------------------------------------------


0.2.0.0 [2015-12-01] (git tag: [0.2.0.0][])
-------

https://hackage.haskell.org/package/dejafu-0.2.0.0

I didn't write proper release notes, and this is so far back I don't really care to dig through the
logs.

[0.2.0.0]: https://github.com/barrucadu/dejafu/releases/tag/0.2.0.0


---------------------------------------------------------------------------------------------------


0.1.0.0 [2015-08-27] (git tag: [0.1.0.0][])
-------

https://hackage.haskell.org/package/dejafu-0.1.0.0

Initial release. Go read the API docs.

[0.1.0.0]: https://github.com/barrucadu/dejafu/releases/tag/0.1.0.0