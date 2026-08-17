# Sludges: student-language extensions to signatures

Package `sludges` extends with additional features to specify typed
signatures the [student languages](https://docs.racket-lang.org/htdp-langs/) ([BSL](https://docs.racket-lang.org/htdp-langs/beginner.html), [BSL+](https://docs.racket-lang.org/htdp-langs/beginner-abbr.html), [ISL](https://docs.racket-lang.org/htdp-langs/intermediate.html), [ISL+](https://docs.racket-lang.org/htdp-langs/intermediate-lam.html), [ASL](https://docs.racket-lang.org/htdp-langs/advanced.html)) of
[How to Design Programs](https://htdp.org/). It is mainly meant to be loaded used as a
[Teachpack](https://docs.racket-lang.org/htdp/) in DrRacket, although
it also works as a standard Racket module.


## Example

Here is an example that works in all student languages. It defines:

- A typed struct `person`, which implicitly defines a data type
  `Person`.

- A recursive data type `Two+List` corresponding to all lists of
  `String`s with two or more elements.

- A function `first-person` with signature `Two+List -> Person`.

```racket
; A Person is a struct (make-person first last),
; where first and last are strings.
(define-struct person [(first String) (last String)])

; A Two+List is one of the following:
;  - a (cons String (cons String '()))  -- a list with exactly two strings
;  - a (cons String Two+List)           -- a list with three or more strings
(define-type Two+List (one-of
                       (ConsOf String (ConsOf String EmptyList))
                       (ConsOf String Two+List)))

; Signature of function first-person
(: first-person (Two+List -> Person))
(define (first-person lst)
  (make-person (first lst) (second lst)))
```

Signatures are checked at runtime. When a check fails, it is reported
similarly to a `check-expect` failure. Here are two examples of
signature violations using the data types `Person` and `Two+List`
defined above.

```racket
; expected a String, but got 'Simpson
(make-person "Homer" 'Simpson)

; expected a Two+List, but got (cons "Homer" '())
(first-person (cons "Homer" '()))
```


## Background: Signatures in the student languages

Since version 8.9, Racket has included several features to
express typed signature and check them at runtime. These features were
originally introduced in the [student
languages](https://docs.racket-lang.org/deinprogramm/) of the German textbook
textbook [Schreibe Dein Programm](https://www.deinprogramm.de/sdp/).

Package `sludges` extends some of these features, and provides other
similar features that are convenient for the HtDP curriculum. It is a
first attempt at implementing some of the features initially discussed
on [Racket
Discourse](https://racket.discourse.group/t/signatures-in-student-languages/4166).


## Installation and usage

Using the command-line `raco` installer:

```
raco pkg install sludges
```

After installation, to use as a teachpack in DrRacket: 

- Go to **Language > Add Teachpack...**.
- In the **Preinstalled HtDP Teachpacks** column (left), select **sludges.rkt**.
- Click **OK**.

or include the module in your program:

```racket
(require sludges)
```

See [INSTALL.md](INSTALL.md) for other ways of installing and using `sludges`.


## Features

Here is an overview of the package's features. See the
[package documentation](https://pkg-build.racket-lang.org/doc/sludges@sludges/index.html)
for a detailed description.

### Data type definitions

`sludges` provides `define-type` to bind signature forms to
variables.  `(define-type T ...)` is essentially a shorthand for
`(define T (signature ...))`, which also works for parametric and
(mutually) recursive definitions.

### Structs with typed fields

- `define-struct/typed` defines a struct whose fields are bound to
  specific types.

- `define-struct` accepts two variants: the regular "untyped"
  `define-struct` that is already available in the student languages,
  or the typed form that is supported by `define-struct/typed`.

### Intervals

`sludges` provides several variants of `integer-from-to` to
express interval data types:

- Unbounded integer intervals: `integer-from` and
  `integer-to`.

- Bounded numeric intervals: `number-from-to`, `number-from<-to`,
  `number-from-<to`, `number-from<-<to`

- Unbounded numeric intervals: `number-from`, `number-to`,
  `number-from<`, `number-<to`

### One of

`one-of` is an alias of `mixed`, which is used to define
itemizations and other kinds of mixed data. The name `one-of` mirrors
the structured natural language descriptions that are used in
HtDP, such as in the comments describing data type `Two+List` defined above.

### Predicates in BSL

Data types based on predicates (using `predicate`) now also work in
BSL/BSL+, provided they are defined with `define-type`:

```racket
(define-type Even (predicate even?))
```

### Predefined data types

In addition the predefined signatures available in the student languages
(`Any`, `Boolean`, `Char`, `ConsOf`, `EmptyList`,
 `False`, `Integer`, `Natural`, `Number`,
 `Rational`, `Real`, `String`, `Symbol`, `True`)
`slugs` also provides:

- `Posn` and `PosnOf` for instances of the struct `posn`.

- `List` for list instances (empty or non-empty).

- `Maybe T` as an alias of `(one-of T False)`

- `Image` for the type of images supported by the [`2htdp/image`](https://docs.racket-lang.org/teachpack/2htdpimage.html) library.

- `KeyEvent` and `MouseEvent` for the enumerations used by the [`2htdp/universe`](https://docs.racket-lang.org/teachpack/2htdpuniverse.html) library.

- `Vector` and `VectorOf` for instances of
  [`vector`](https://docs.racket-lang.org/htdp-langs/advanced.html#%28def._htdp-advanced._%28%28lib._lang%2Fhtdp-advanced..rkt%29._vector%29%29)

- `Void` for the type of `(void)` returned by `set!` expressions.

Note that `Vector`, `VectorOf` and `Void` only work in
[ASL](https://docs.racket-lang.org/htdp/index.html#%28part._.Ht.D.P_.Advanced_.Student%29),
where vectors and mutable variables are available.

### Signature violations

Signature violations are reported as:

```
expected a DataType, but got value in violation-loc, signature signature-loc
```

This denotes using a `value` that is not an instance of
`DataType`. The offending value was passed at location
`violation-loc`, and it violates the signature at location
`signature-loc`.

Since signature violations do not block execution but are simply
logged and displayed to the user, it is relatively common that a
signature violation triggers a cascade of other, related signature
violations. To avoid overwhelming the user with too many violations,
`sludges` reports by default only the first violation per pair
`(signature object, datatype name)`. Despite this filtering, it is
possible to get multiple violation reports for the same root cause. In
addition, the filtering may sometimes result in masking: a certain
signature violation is only reported after a different, but related
signature violation has been resolved.

Signature violation filtering can be changed with module parameters
`max-signature-violations` and `signature-violation-dedup`.


## Implementation

See [IMPL.md](IMPL.md) for some implementation details, and a list of known limitations.
