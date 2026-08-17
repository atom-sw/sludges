# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Racket package versions are not semantic versions: `valid-version?` accepts
`X.Y` or `X.Y.Z[.W]`, and rejects anything ending in `.0` past the
two-component form.  So this project numbers releases `1.0`, `1.1`, `1.0.1`,
and never `1.0.0` or `2.0.0`.

## [Unreleased]

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

[Unreleased]: https://github.com/atom-sw/sludges/compare/v1.0...HEAD
[1.0]: https://github.com/atom-sw/sludges/releases/tag/v1.0
