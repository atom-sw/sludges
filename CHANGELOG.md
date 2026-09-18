# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Racket package versions are not semantic versions: `valid-version?` accepts
`X.Y` or `X.Y.Z[.W]`, and rejects anything ending in `.0` past the
two-component form.  So this project numbers releases `1.0`, `1.1`, `1.0.1`,
and never `1.0.0` or `2.0.0`.

## [Unreleased]

## [1.1.1]

### Fixed

- The package build service reported a failing test for
  `sludges/examples/readme-examples.rkt`.  That file demonstrates the README's
  signature violations, and a violation lets execution continue, so it goes on
  to raise: it is a demonstration that `raco test` can only score as a failure.
  It is no longer run as a test, and is still compiled.

## [1.1]

### Added

- `define-type-constructor`, which introduces a new type constructor from a
  recognizer and one selector per parameter, the way `ConsOf` and `PosnOf`
  head a type form.
- `Cons`, another name for the student languages' `ConsOf`, capitalizing
  `cons` the way `Add1` capitalizes `add1`. The two spellings are
  interchangeable, including within one definition.
- `Add1`, a positive exact integer whose predecessor satisfies its argument,
  so that the natural numbers can be described by the recursion that defines
  them: `(define-type Natural (one-of (enum 0) (Add1 Natural)))`. It is `add1`
  with its domain restricted to the nonnegative exact integers, and so is
  deliberately narrower than `add1`, which also accepts negative and
  non-integer numbers: a faithful lift would make that recursion run forever
  on `-1` instead of rejecting it.

### Changed

- `define-type` now reports a head that is not a type constructor when the
  definition is evaluated, naming the type, the source location and the form
  to use instead. Writing `(cons Any L)` or `(add1 N)` in a type used to be
  accepted silently and then fail inside DeinProgramm on first use.

## [1.0]

First public release.

### Added

- `define-type`, which binds a signature form to a name, including parametric
  and mutually recursive definitions.
- `define-struct/typed`, and a `define-struct` that also accepts field
  signatures, shadowing the student languages' own.
- `define-header` and `define-template`, for the intermediate steps of the
  design recipe.
- `one-of`, an alias of `mixed` that mirrors how HtDP describes itemizations in
  prose.
- Interval types: `integer-from-to`, `integer-from`, `integer-to`,
  `number-from-to`, `number-from<-to`, `number-from-<to`, `number-from<-<to`,
  `number-from`, `number-from<`, `number-to`, `number-<to`.
- Predefined types beyond those the student languages already offer: `Posn`,
  `PosnOf`, `List`, `Maybe`, `Image`, `KeyEvent`, `MouseEvent`, `Vector`,
  `VectorOf`, `Void`.
- Support for `predicate` types in BSL and BSL+, when defined through
  `define-type`.
- Signature violations reported as "expected a T, but got V".
- A standalone teachpack, `sludges/dist/sludges.rkt`, that can be added in
  DrRacket without installing the package.

[Unreleased]: https://github.com/atom-sw/sludges/compare/v1.1.1...HEAD
[1.1.1]: https://github.com/atom-sw/sludges/releases/tag/v1.1.1
[1.1]: https://github.com/atom-sw/sludges/releases/tag/v1.1
[1.0]: https://github.com/atom-sw/sludges/releases/tag/v1.0
