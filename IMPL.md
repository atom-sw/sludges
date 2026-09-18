# Implementation notes for Sludges

This document outlines the main features of the implementation of
`sludges`, roughly following the same order as [`main.rkt`](sludges/main.rkt).

## Predefined signatures

### Signatures based on predicates

The implementations of signatures `Posn`, `Image`, `MouseEvent`,
`KeyEvent`, `List`, `Vector`, and `Void` are straightforward
definitions based on the corresponding predicates. For example, `Posn`
is simply `(predicate posn?)`.

Signatures `MouseEvent` and `KeyEvent` are based on predicates
`mouse-event?` and `key-event?` from library `2htdp/universe`. To
avoid loading the whole library with these signature definitions,
`sludges` uses a `lazy-require`, so that `2htdp/universe` is only
loaded when these signatures are actually applied.

### Parametric signatures

The definitions of the parametric signatures `PosnOf`, `VectorOf`, and
`Maybe` are considerably more complex to improve error reporting. For
example, we could implement `Maybe` simply with `mixed`:

```racket
(define (Maybe T) (signature (mixed T False)))
```

This would be functionally equivalent to its actual
implementation. However, applications of `Maybe` would carry their our
violation handler, which is different from the one introduced by `sludges`
(which is described below).

To avoid this, the actual definition of `Maybe` wraps an `inner`
definition (which is essentially equivalent to `(mixed T False)`)
within an `outer` signature that intercepts signature violations from
the `inner` handler and rewrites their error message using the
`sludges` format and the `Maybe` name.

The implementation of `VectorOf` uses a similar wrapping for the same
reason.

The implementation of `PosnOf` uses a similar wrapping where `outer`
re-assigns the source location of the `inner` signature check
procedure to itself (i.e., the whole signature object). This ensures
that the location of the violation of a signature involving `PosnOf`
does not refer to the definition of `PosnOf` in `main.rkt`, but to its
application in the signature in client code.


### Intervals

The definitions of interval signatures are all based on
predicates. For example `(integer-from-to lo hi)` boils down to the
predicate `(lambda (n) (and (integer? n) (<= lo n) (<= n hi))`. In
addition:

- The signature constructors check that their bounds are valid.

- The signatures use `make-predicate-signature` instead of `predicate`
  directly. The two approaches are functionally equivalent. However,
  using `make-predicate-signature` improves error reporting, because
  it registers a descriptive name (such as `integer-from-to`) and sets
  its source location fo `#f`, so that violations do not refer to
  locations in `main.rkt`.

Interval signatures are only usable within `define-type`; in contrast
a direct usage such as `(: N (integer-from-to 3 5))` is rejected as
syntax error. This is due to how signature checking works in the
student languages, and it cannot be easily worked around. In the above
signature for `N`, `(integer-from-to 3 5)` is processed by
`parse-signature`. There, it matches the `(?signature-abstr ?signature
...)` pattern, which recursively parses `3` and `5` as
sub-signatures. This fails becaus literal numbers aren't valid
signature expressions. Avoiding this behavior would require to
redefine how `parse-signature` works in the definition of `:`, which
is beyond the scope of `sludges`.


## Typed structs

Macro `define-struct/typed` implements typed structs by delegating to
the core helper function `expand-typed-struct`. This works as follows:

1. It recovers the correct signature (type) name associated with the
   struct, consistently with the same rewriting done by the student
   languages.

2. It identifies in which student language it is being expanded. This
   information is needed because `define-struct` works slightly
   differently in certain student languages. In particular, in
   BSL/BSL+ all struct-related functions (constructor, selectors, ...)
   must be first order, and in ASL structs are equipped with setters.

3. Based on the identified student language, it delegates the
   expansion to the correct variant of `define-struct`. The expansion
   is first performed in local `expanded`.

4. Expansion `expanded` is fed through `rewrite-define-values`, which
   revises the expanded definitions as follows. First, the signature
   `Struct` associated with a struct `struct` is re-defined as
   equivalent to `NameOf field-type ...`, which enforces the typed
   constraints. Second, if used within BSL/BSL+, it calls
   `make-first-order-wrappers` to make all struct-related functions
   first order.

Two other details of the rewrite performed by `rewrite-define-values`
are worth pointing out:

5. Helper `wrap-struct-procs` provides signatures for all
   struct-related functions. This is only used by typed structs, since
   the plain `define-struct` of student languages does not equip
   constructors, selectors, and predicates of structures with any
   signatures (but similar errors are caught as runtime errors).

6. Helper `no-arbitrary-sig` is used in the definition of parametric
   signatures `StructOf`. It simply wraps the parameters with a
   promise, which delays their eager recursive evaluation. With this
   tweak, one can use `StructOf` (and thus also `Struct` of typed
   structs) with parameters that are forward or self references. For
   example, the following definition is only possible with this wrapping.

```racket
(define-struct/typed person
  [(name String) (children (ListOf Person))])

(define BART (make-person "Bart" '()))
(define HOMER (make-person "Homer" (list BART)))
```


## Shadowing of `define-struct`

Macro `define-struct` redefines (shadows) the native `define-struct`,
so that both typed and untyped versions are available under the same
name. It accepts two forms:

1. The untyped form `(define-struct name [field ...])` is simply
   expanded to the native `define-struct` of the correct student
   language.

2. The typed form `(define-struct name [(field sig) ...])` is passed
   to `expand-typed-struct` discussed above.

Any other form (for example, one where some fields have a signature
and some don't) is still passed to the native `define-struct` to
reproduce its error messages.


## Mixed signatures: `one-of`

Macro `one-of` is simply defined as an alias of `mixed`.


## Named type definitions: `define-type`

At its core, macro `define-type` is a simple shorthand for a
combination of `define` and `signature:

```racket
(define-type T sig-form)
; essentially rewrites to:
(define T (signature sig-form))
```

On top of this, `define-type` introduces several normalizations of the
`sig-form` that are useful to work around some limitations of the
signature DSL in the student languages.

### Supporting `predicate` in BSL

In BSL and BSL+, functions are not first-class. Therefore, signature
using `predicate` are effectively unusable.  For example, `(predicate
odd?)` is rejected with an error `expected a function call` where
`odd?` appears.

The implementation of `define-type` works around this limitation by
wrapping with `first-order->higher-order` any `define-type` with a
`predicate` at the outermost level:

```racket
(define-type Odd (predicate odd?))
; essentially rewrites to:
(define Odd (signature (predicate (first-order->higher-order odd?))))
```

In BSL/BSL+, `first-order->higher-order` takes a first-order function
name and produces it as a value, so that it can be used inside
`predicate`. The same function returns its input unchanged in the
other student languages, where it is a harmless wrapper.

### Intervals expansion

Above, we discussed how the interval signatures (e.g.,
`integer-from-to`) do not really work in signature forms because
`parse-signature` insists on recursively parsing its arguments, and
rejects numeric bounds because they are not valid signatures.

Before passing its definition to `signature`, `define-type` expands
any interval with `expand-interval-forms`, which inlines the predicate
identifying the interval's valid values. This expanded form can be
parsed by `parse-signature` without problems.

```racket
(define-type Int3-5 (integer-from-to 3 5))        ; OK
(define Int3-5 (signature (integer-from-to 3 5))) ; syntax error
```

Precisely, `expand-interval-forms` takes any signature form and
recursively goes into its "combinators" such as `mixed` and `enum`,
whereas it stops at `predicate` applications, since those need no
rewriting as they already include regular expressions.

### Normalizations

`define-type` applies `fold-consof-prefixes` to its signature argument
to normalize forms using `mixed` to work around two issues with how
signature checking is implemented.

#### Normalization 1: Collecting `ConsOf` prefixes

The following recursive type definition `Two+List` of lists with two
or more elements introduces spurious signature violations:

```racket
(define Two+List (signature
                  (mixed
                   (ConsOf Any (ConsOf Any EmptyList))
                   (ConsOf Any Two+List))))


(: L3 Two+List)
(define L3 (list 1 2 3)) ; spurious signature violation!
```

This is because signature checking incorrectly rejects values when a
mixed form contains multiple instances of `ConsOf` with different
nesting depth. To avoid such spurious errors, `fold-consof-prefixes`
transforms nested instances of `ConsOf` by collecting a common prefix:

```racket
(define-type Two+List (mixed
                       (ConsOf Any (ConsOf Any EmptyList))
                       (ConsOf Any Two+List)))
; rewrites to:
(define Two+List (signature
                  ; collects common prefix 'ConsOf Any'
                  (ConsOf Any
                          (mixed (ConsOf Any EmptyList)
                                 Two+List))))
```

This rewriting is handled correctly by the signature checking
procedure.


#### Normalization 2: `combined` wrapping

Consider the following recursive type definitions `1+L` and `2+L`,
modeling numeric lists with at least one or two elements. 

```racket
(define 1+L (signature (ConsOf Number (mixed 1+L EmptyList))))
(define 2+L (signature (ConsOf Number (mixed 2+L (ConsOf Number EmptyList)))))
```

Since both definitions are already normalized by collecting the common
`ConsOf` prefix, they work correctly with the signature checking when
they are applied to distinct variables. If we try to apply them to two
aliased variables, signature checking crashes:

```racket
; OK
(: L1 2+L)
(define L1 (list 1 2 3))

; runtime error from 'andmap'
(: L2 1+L)
(define L2 L1)
```

This happens because the signature DSL applies its own normalization
to signature forms; in particular, it flattens nested applications of
`mixed`. In the example, `1+L` and `2+L` get flattened into lists of
different length.

Now, since `L1` and `L2` are aliased, there are effectively two
signatures `2+L` and `1+L` attached to the same variable. This does
not play well with the signature checking procedure, which tacitly
assumes that all `mixed` signatures for the same variable have the
same flattened length and tries to merge them. Hence, the error
triggered by `andmap`.

Normalization 2 avoids this issue by wrapping the inner `mixed` within
a `combined`, as shown in the following:

```racket
(define 1+L (signature (ConsOf Number (combined (mixed 1+L EmptyList)))))
(define 2+L (signature (ConsOf Number (combined (mixed 2+L (ConsOf Number EmptyList))))))
```

Form `combined` expresses a conjunction of signatures, which is the
same as an identity when applied to a single argument as in this
normalization. The only effect we are interested in is that the
flattening performed by the signature DSL stops at applications of
`combined`. This way, `1+L` and `2+L` are not flattened and merged,
and hence the abovementioned failure is avoided completely, while
signature checking still works correctly.


## Error filtering and reporting

Package `sludges` filters and reformats the signature violation
errors, with the goal of making them more clear and precise. This is
done by redefining the signature violation handler
`signature-violation-proc`.[^1] This does not always work (see
[limitations](#limitations)), but it is useful at least in some basic
cases.

[^1]: Precisely, we redefine `signature-violation-proc` in different
      parts of `sludges`'s implementation, so as to tweak its behavior
      to how certain signature forms report violations to the handler.


### Signature violation messages

The default signature violation error message has the form:

```
got <VALUE> in <USAGE-LOC>, signature in <SIG-LOC>
```

where location `<USAGE-LOC>` includes an expression with `<VALUE>`
that violates the signature at location `<SIG-LOC>`.

We redefine the violation handler to use the form:

```
expected a <SIG-NAME>, but got <VALUE> in <USAGE-LOC>, signature in <SIG-LOC>
```

where `<SIG-NAME>` is the name of the signature type.

This format is the one recommended in the [HtDP
guidelines](https://docs.racket-lang.org/htdp/), which is also adopted
to report test failures: "State the constraint that was violated, then
contrast with what was found."

### Violation location 

As a result of the rewritings introduced by the macros in `sludges`,
sometimes the location `<SIG-LOC>` of a violated signature declaration
or the location `<USAGE-LOC>` of a value that violates a signature
point to the files implementing `sludges` instead of the source code
of the program.

This is addressed in two ways:

1. Function `user-srcloc` augments the standard
   `continuation-marks-srcloc` as follows.  When it processes
   signature violations, it discards references to any locations in
   `sludges` or other basic modules.  Like its counterpart in
   `test-engine/srcloc`, it reads the stack through the parameter
   `errortrace-continuation-mark-set->context`, which DrRacket sets
   when it annotates the program; outside DrRacket the parameter is
   unset and `user-srcloc` returns `#f`, leaving the location
   untouched.

2. We intercept the original `signature-violation-proc` and, before
   calling it, we try to capture the correct user-code location of the
   items involved in a signature violation. When building the error
   message, this information will be used if it is available.

### Deduplication

Each signature violation is assigned a bucket based on one of three
criteria:

1. If parameter `signature-violation-dedup` is `'type-name`, then all
   violations of a signature with the same *name* go into the same
   bucket.

2. If parameter `signature-violation-dedup` is `'signature`, then all
   violations of a signature with the same *name* and *signature
   object* go into the same bucket.

3. If parameter `signature-violation-dedup` is `'object`, then all
   violations of a signature with the same *name* and *violating
   object* go into the same bucket.

Then, only the first `max-signature-violations` violations in each
bucket are reported; the others are discarded.


## Limitations

Several of the (known) limitations of `sludges` stem from the fact
that it is applied on top of the existing signature form DSL and its
checking mechanisms. This may result in inconsistent behavior
(depending on whether we go through `sludges` rewritings or we use the
"native" signature forms directly) and occasional interaction bugs.

### Signature forms

Several signature declarations work properly only if they are
expressed within a `define-type`. The most obvious example is the
usage of [intervals](#intervals) discussed above.

The normalization performed by `define-type` may not work correctly
for complex, mutually recursive data type definitions. If you find
examples of this, please report them to the package maintainers.

### Error reporting

The overriding of the signature violation procedure introduced by
`sludges` is not always effective. Some signature violations that
originate in the "native" signature checking procedure escape our
filtering. This may result in additional, redundant error messages;
error messages that use a different format; and error messages that
refer to source locations outside user code.

For example, the following signature violation results in two error
messages:

```racket
(define-struct person [(first String) (last String)])

(: P Person)
(define P (make-person 7 "Simpson"))
```

In addition to `expected a String, but got 7`, the same violation is
reported as `expected a first, but got 7`, which comes from how the
original `define-struct` registers fields with the violation handler.

The rule of thumb is that `sludges`'s overridden signature violation
procedure is active only if `define-type` has to rewrite the given
signature; in that case, it also has a chance to inject a proper name,
which is enough information for the overridden violation handler to
process related signature violations. In contrast, if `define-type` is
either not used or simply adds a `signature` at the outermost level,
then the violation handler will not find the proper information, and
hence it will fall back to the default error message behavior.

### Other limitations

The wrapping of fields performed by `no-arbitrary-sig` in
[`define-struct/typed`](#typed-structs) allegedly is incompatible with
[Quickcheck](https://docs.racket-lang.org/quickcheck/index.html). This
does not seem to be much of a problem for student languages.

The execution of tests, which also drives the signature checking
process, may behave differently when executed within DrRacket as
opposed to when launched with `raco test`. While the test/signature
check outcomes should be consistent, the way errors and violations are
reported may differ. In particular, the command line test runner does
not report locations of signature violations but only locations of the
violated signatures. This is also not a major issue, given that
students are expected to run tests within DrRacket.


## AI usage

This package's source code was mainly written with
[OpenCode](https://opencode.ai/) connected to Claude Opus/Sonnet
backend. Later revisions used Claude Code. The documentation,
including some of these implementation notes, were written 
which occasionally led to revision of the source code.
