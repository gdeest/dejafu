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


0.4.0.1 [2017-03-20] (git tag: [hunit-dejafu-0.4.0.1][])
-------

https://hackage.haskell.org/package/hunit-dejafu-0.4.0.1

### Miscellaneous

- Now supports HUnit 1.6.

[hunit-dejafu-0.4.0.1]: https://github.com/barrucadu/dejafu/releases/tag/hunit-dejafu-0.4.0.1


---------------------------------------------------------------------------------------------------


0.4.0.0 [2017-02-21] (git tag: [hunit-dejafu-0.4.0.0][])
-------

https://hackage.haskell.org/package/hunit-dejafu-0.4.0.0

### Test.HUnit.DejaFu

- All the functions which did take a `Bounds` now take a `Way` instead and support random scheduling
  as well.
- The `Way` type from dejafu is now re-exported.

### Miscellaneous

- The minimum supported version of dejafu has been increased to 0.5 (from 0.2)

[hunit-dejafu-0.4.0.0]: https://github.com/barrucadu/dejafu/releases/tag/hunit-dejafu-0.4.0.0


---------------------------------------------------------------------------------------------------


0.3.0.3 [2016-10-22] (git tag: [hunit-dejafu-0.3.0.3][])
-------

https://hackage.haskell.org/package/hunit-dejafu-0.3.0.3

### Miscellaneous

- Now supports HUnit 1.4 and 1.5.

[hunit-dejafu-0.3.0.3]: https://github.com/barrucadu/dejafu/releases/tag/hunit-dejafu-0.3.0.3


---------------------------------------------------------------------------------------------------


0.3.0.2 [2016-09-10] (git tag: [hunit-dejafu-0.3.0.2][])
-------

https://hackage.haskell.org/package/hunit-dejafu-0.3.0.2

### Miscellaneous

- Now supports concurrency 1.0.0.0 and dejafu 0.4.0.0

[hunit-dejafu-0.3.0.2]: https://github.com/barrucadu/dejafu/releases/tag/hunit-dejafu-0.3.0.2


---------------------------------------------------------------------------------------------------


0.3.0.1 [2016-05-26] (git tag: [hunit-dejafu-0.3.0.1][])
-------

https://hackage.haskell.org/package/hunit-dejafu-0.3.0.1

### Miscellaneous

- Now supports GHC 8.

[hunit-dejafu-0.3.0.1]: https://github.com/barrucadu/dejafu/releases/tag/hunit-dejafu-0.3.0.1


---------------------------------------------------------------------------------------------------


0.3.0.0 [2016-04-28] (git tag: [hunit-dejafu-0.3.0.0][])
-------

https://hackage.haskell.org/package/hunit-dejafu-0.3.0.0

### Test.HUnit.DejaFu

- New `Assertable` and `Testable` instances for `ConcST t ()` and `ConcIO ()`.
- The `Bounds` type from dejafu is now re-exported.

### Miscellaneous

- Now supports dejafu 0.2 (again).

[hunit-dejafu-0.3.0.0]: https://github.com/barrucadu/dejafu/releases/tag/hunit-dejafu-0.3.0.0


---------------------------------------------------------------------------------------------------


0.2.1.0 [2016-04-03] (git tag: [hunit-dejafu-0.2.1.0][])
-------

**This version was never pushed to hackage, whoops!**

### Miscellaneous

- Now supports dejafu 0.3, but drops support for dejafu 0.2.

[hunit-dejafu-0.2.1.0]: https://github.com/barrucadu/dejafu/releases/tag/hunit-dejafu-0.2.1.0


---------------------------------------------------------------------------------------------------


0.2.0.0 [2015-12-01] (git tag: [0.2.0.0][])
-------

https://hackage.haskell.org/package/hunit-dejafu-0.2.0.0

Initial release. Go read the API docs.

[0.2.0.0]: https://github.com/barrucadu/dejafu/releases/tag/0.2.0.0