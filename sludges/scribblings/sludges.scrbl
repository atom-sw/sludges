#lang scribble/manual

@(require (for-label sludges
                     (except-in racket/base define-struct)))

@; Cross-references to Signatures sections in the HtDP student language docs.
@(define htdp-langs-doc '(lib "scribblings/htdp-langs/htdp-langs.scrbl"))
@(define (bsl-link)  (seclink "beginner-signatures"           #:doc htdp-langs-doc "BSL"))
@(define (bslp-link) (seclink "beginner-abbr-signatures"     #:doc htdp-langs-doc "BSL+"))
@(define (isl-link)  (seclink "intermediate-signatures"      #:doc htdp-langs-doc "ISL"))
@(define (islp-link) (seclink "intermediate-lambda-signatures" #:doc htdp-langs-doc "ISL+"))
@(define (asl-link)  (seclink "advanced-signatures"          #:doc htdp-langs-doc "ASL"))

@title[#:tag "sludges" #:style '(toc)]{Sludges: Extensions to Signatures for HtDP Student Languages}

@defmodule[sludges]

The @racketmodname[sludges] teachpack extends the built-in signature
system of HtDP student languages.  It provides named type definitions,
typed struct definitions, predefined signatures for common types,
interval signatures for interval ranges, and helpers useful while
following the design recipe.

Load it in your program with:

@racketblock[
(require sludges)
]

@table-of-contents[]


@; ========================================
@section[#:tag "sludges-signatures-overview"]{Signatures}

A @bold{signature} denotes a data type (a set of values)
and is specified as a @italic{signature form},
a special syntax that can only used in @racket[:] signature declarations,
inside @racket[signature] expressions, or in @racketmodname[sludges]'s
@racket[define-type] definitions.

@nested{In a signature form, any name starting with @racketidfont{%}
is a @italic{signature variable} that stands for any signature data type.
Signature variables are @bold{not enforced}: they accept any value
without checking, behaving like @racket[Any].  Their purpose is
documentation only. For example, the following code does not raise
any signature violation.}

@racketblock[
(: same (%T -> %T))
(define (same x) #false)

(check-expect (same 7) #false)
]





@; ========================================
@section[#:tag "sludges-type-defs"]{Named Type Definitions}

@defform*[((define-type name signature-form)
           (define-type (name param ...) signature-form))]{

Defines a named signature.

The first form binds @racket[name] to the signature described by
@racket[signature-form]:

@racketblock[
(define-type StringOrFalse (one-of String False))

(: X PossiblyString)
(define X "hello")
]

The second form defines @racket[name] as a function that takes
signature parameters and returns a new signature:

@racketblock[
(define-type (Either A B) (one-of A B))

(: string->number/maybe (String -> (Either Number String)))
; Converts the input string to a number of possible, otherwise returns it unchanged
]

@racket[define-type] can also describe recursive types:

@racketblock[
(define-type List<Number> (one-of Empty (ConsOf Number NumberList)))
]

Available in: all student languages.
}

@defform[(one-of signature-form ...)]{

An alternative name for @racket[mixed].

@racketblock[
(define-type NumberOrBool (one-of Number Boolean))
]

Available in: all student languages.
}

@; ========================================
@section[#:tag "sludges-structs"]{Typed Struct Definitions}

@defform*[((define-struct name [(field-name sig-form) ...])
           (define-struct name [field-name ...]))]{

Defines a struct and a type based on it.  The first form uses typed
field specifications; the second is the standard untyped form.

All field specifications must use the same style: either all typed or
all untyped.  Square brackets and parentheses are interchangeable.

@bold{Typed form.}  When every field is written as a
@racket[(field-name sig-form)] pair, @racketmodname[sludges] adds signature checking
to all generated procedures:

@racketblock[
(define-struct person [(first String) (last String)])

(make-person "Homer" "Simpson")   (code:comment "OK")
(make-person "Marge" 'Simpson)    (code:comment "signature violation: expected a String")
]

This defines:

@itemlist[
  @item{@racketidfont{make-person} as a constructor with signature
        @racketidfont{String String -> Person}.  Passing a
        wrong-typed argument reports a signature violation.}
  @item{@racketidfont{person?} as a predicate with signature
        @racketidfont{Any -> Boolean}.}
  @item{@racketidfont{person-first}, @racketidfont{person-last} as
        selectors with signatures @racketidfont{Person -> String}.}
  @item{@racketidfont{Person} as a signature matching any
        valid instance of struct @racketidfont{person}.}
  @item{@racketidfont{PersonOf} as a parametric signature constructor:
        @racketidfont{(PersonOf Sig1 Sig2)} matches
        @racketidfont{person} values whose fields satisfy
        @racketidfont{Sig1} and @racketidfont{Sig2} respectively.}
]

@bold{Untyped form.}  When each field is a plain identifier,
@racket[define-struct] behaves as the built-in @racketidfont{define-struct}.

@racketblock[
(define-struct Pair [a b])

(make-pair 3 4)       (code:comment "OK")
(make-pair 3 "four")  (code:comment "OK")
]

This defines:

@itemlist[
  @item{@racketidfont{make-pair} as a constructor with signature
        @racketidfont{Any Any -> Pair}.}
  @item{@racketidfont{pair?} as a predicate with signature
        @racketidfont{Any -> Boolean}.}
  @item{@racketidfont{pair-a}, @racketidfont{pair-b} as
        selectors with signatures @racketidfont{Pair -> Any}.}
  @item{@racketidfont{Pair} as a signature matching any
        valid instance of struct @racketidfont{pair}.}
  @item{@racketidfont{PairOf} as a parametric signature constructor:
        @racketidfont{(PairOf Sig1 Sig2)} matches
        @racketidfont{pair} instances whose fields satisfy
        @racketidfont{Sig1} and @racketidfont{Sig2} respectively.}
]

Violations of signatures involving untyped structs are actually
detected by the student languages' regular runtime error checking, not
by signature checking.  For example, evaluating @racket[(pair-first
3)] gives the error @racketcommentfont{pair-first: expects a pair,
given 3}, which is not a signature violation.

@bold{Naming convention.} The generated signature names use TitleCase
with hyphens removed. That is, the struct name is capitalized, hyphens
are removed, and the first letter following an hyphen is
capitalized. For example, a struct called @racketidfont{foo-bar-3baz}
produces signatures @racketidfont{FooBar3Baz} and
@racketidfont{FooBar3BazOf}.

Available in: all student languages.  In BSL and BSL+,
constructors and selectors are first-order. In ASL, fields are mutable.
}

@defform[(define-struct/typed name ((field-name sig-form) ...))]{

Equivalent to @racket[define-struct] with typed fields.
Prefer @racket[define-struct] in new code.

Available in: all student languages.
}

@; ========================================
@section[#:tag "sludges-sigs"]{Predefined Signatures}

@defthing[Image signature?]{
A signature for an image produced by the
@racketmodname[2htdp/image] library.

@racketblock[
(: BACKGROUND Image)
(define BACKGROUND (empty-scene 400 300))
]

Available in: all student languages.
}

@defthing[Posn signature?]{
A signature for a @racket[posn] value.

@racketblock[
(: ORIGIN Posn)
(define ORIGIN (make-posn 0 0))
]

Available in: all student languages.
}

@defproc[(PosnOf [x-sig signature?] [y-sig signature?]) signature?]{
A signature for a @racket[posn] whose
@racketidfont{posn-x} field satisfies @racket[x-sig] and whose
@racketidfont{posn-y} field satisfies @racket[y-sig].

@racketblock[
(: move/x (Integer (PosnOf Integer Integer) -> (PosnOf Integer Integer)))
(define (move/x dx p)
  (make-posn (+ dx (posn-x p)) (posn-y p)))
]

Available in: all student languages.
}

@defthing[MouseEvent signature?]{
A signature for strings that characterize mouse events, as used by
@racketmodname[2htdp/universe].

Available in: all student languages.
}

@defthing[KeyEvent signature?]{
A signature for strings that characterize keyboard events, as used by
@racketmodname[2htdp/universe].

Available in: all student languages.
}

@defthing[List signature?]{
A signature for any list.  Equivalent to
@racket{ListOf Any}.

@racketblock[
(: STUFF List)
(define STUFF (list 1 "two" #true))
]

Available in: all student languages.
}

@defproc[(Maybe [sig signature?]) signature?]{
A signature for either a value satisfying @racket[sig]
or @racket[#false].

@racketblock[
(: find (String (ListOf String) -> (Maybe Natural)))
; The index of the first occurrence of s in lst,
; or #false if s is not found in lst.
]

Available in: all student languages.
}

@defthing[Vector signature?]{
A signature for a vector.

Available in: ASL.
}

@defproc[(VectorOf [sig signature?]) signature?]{
A signature for a vector whose elements satisfy
@racket[sig].

@racketblock[
(: GRADES (VectorOf Number))
(define GRADES (vector 7.0 8.5 9.5))
]

Available in: ASL.
}

@defthing[Void signature?]{
A signature for the result of @racket[set!],
@racket[vector-set!], as well as @racket[(void)]
in student languages.

@racketblock[
(: reset! (-> Void))
(define (reset!) (set! COUNTER 0))
]

Available in: ASL.
}

@; ========================================
@section[#:tag "sludges-intervals"]{Intervals}

Intervals describe numeric ranges.  A @litchar{<} in the name
indicates an open (exclusive) endpoint; absence of @litchar{<} means
closed (inclusive).

For technical reasons of how signatures are implemented in the student languages,
interval signatures are currently only usable within @racket[define-type].

@racketblock[
 ; This works
(define-type Int-3-5 (integer-from-to 3 5))
(: M Int-3-5)
(define M 4)

; This gives a syntax error
(: N (integer-from-to 3 5)) 
(define N 4)   
]


@subsection[#:tag "sludges-int-intervals"]{Integer Intervals}

Integer bounds are always inclusive, since bounded integer intervals
are always closed.

@defproc[(integer-from-to [lo exact-integer?] [hi exact-integer?]) signature?]{
Signature for integers in the closed interval
[@racket[lo], @racket[hi]].
@racket[lo] must be less than or equal to @racket[hi].

@racketblock[
(: DICE (integer-from-to 1 6))
]

Available in: all student languages.
}

@defproc[(integer-from [lo exact-integer?]) signature?]{
Signature for integers greater than or equal to @racket[lo]:
[@racket[lo], +inf).

@racketblock[
(define-type PosInts (integer-from 1))
]

Available in: all student languages.
}

@defproc[(integer-to [hi exact-integer?]) signature?]{
Signature for integers less than or equal to @racket[hi]:
(-inf, @racket[hi]].

@racketblock[
(define-type NegInts (integer-to -1))
]

Available in: all student languages.
}

@subsection[#:tag "sludges-num-intervals"]{Real-Number Intervals}

Bounded intervals take two arguments.  A @litchar{<} immediately
before or after the hyphen signals an open endpoint.

@defproc[(number-from-to [lo real?] [hi real?]) signature?]{
Signature for (real) numbers in [@racket[lo], @racket[hi]].

Available in: all student languages.
}

@defproc[(number-from<-to [lo real?] [hi real?]) signature?]{
Signature for (real) numbers in (@racket[lo], @racket[hi]].

Available in: all student languages.
}

@defproc[(number-from-<to [lo real?] [hi real?]) signature?]{
Signature for (real) numbers in [@racket[lo], @racket[hi]).

Available in: all student languages.
}

@defproc[(number-from<-<to [lo real?] [hi real?]) signature?]{
Signature for (real) numbers in (@racket[lo], @racket[hi]).

Available in: all student languages.
}

Unbounded intervals take a single argument.

@defproc[(number-from [lo real?]) signature?]{
Signature for (real) numbers in [@racket[lo], +inf).

Available in: all student languages.
}

@defproc[(number-from< [lo real?]) signature?]{
Signature for (real) numbers in (@racket[lo], +inf).

Available in: all student languages.
}

@defproc[(number-to [hi real?]) signature?]{
Signature for (real) numbers in (-inf, @racket[hi]].

Available in: all student languages.
}

@defproc[(number-<to [hi real?]) signature?]{
Signature for (real) numbers in (-inf, @racket[hi]).

Available in: all student languages.
}

@; ========================================
@section[#:tag "sludges-design-recipe"]{Design Recipe Helpers}

The design of a function @racket[fun] according to the
@hyperlink["https://htdp.org/2026-2-25/Book/part_preface.html#(part._sec~3asystematic-design)"]{HtDP
design recipe} follows an incremental process, which produces
successive versions of @racket[fun] that add details in steps. The
three main artifacts are:

@itemlist[#:style 'ordered
  @item{The @italic{header}: a stub implementation of @racket[fun] that
        does nothing other than returning a default value of the expected type.}
  @item{The @italic{template}: an incomplete implementation of @racket[fun]
        that captures the structure of the input types.}
  @item{The @italic{implementation}: a complete implementation of @racket[fun],
        obtained by filling in the template's missing parts and rearranging its elements.}
]

Since all three artifacts are definitions for the same function @racket[fun],
one has to comment out the header before being able to define the template,
and to comment out the template before being able to define the implementation.

The helpers @racket[define-header] and @racket[define-template]
simply allow one to leave headers and templates in the code
without commenting them out, as demonstrated in this example.

@racketblock[
(: count (List -> Natural))

(code:comment "effectively ignored")
(define-header (count lst) 0)

(code:comment "effectively ignored")
(define-template (count lst)
  (cond
    [(empty? lst) ...]
    [else (... (first lst) (count (rest lst)) ...)]))

(define-template (count lst)
  (cond
    [(empty? lst) 0]
    [else (+ 1 (count (rest lst)))]))
]



@defform[(define-header (name arg ...) body)]{

Expands to @racket[(void)] at run time, so that the subsequent
@racket[define] of the same function does not cause a duplicate
definition error.

Available in: all student languages.
}

@defform[(define-template (name arg ...) body)]{

Expands to @racket[(void)] at run time, so that the subsequent
@racket[define] of the same function does not cause a duplicate
definition error.

Available in: all student languages.
}

@; ========================================
@section[#:tag "sludges-student-sigs"]{Student Language Signatures}

Signature declarations and signature forms are part of the HtDP
student languages: see their documentation in @bsl-link[],
@bslp-link[], @isl-link[], @islp-link[], and @asl-link[].  Their main
features are repeated here for reference, since
@racketmodname[sludges] extends them.

@subsection[#:tag "sludges-colon"]{Signature Declarations}

@defform[(: name signature-form)]{

Attaches @racket[signature-form] to the definition of @racket[name].
There must be a definition of @racket[name] somewhere in the program.

@racketblock[
(: AGE Integer)
(define AGE 42)

(: area-of-square (Number -> Number))
(define (area-of-square len)
  (sqr len))
]
}

When running the program, Racket checks whether the signatures attached
with @racket[:] actually match the values of the variables.  If
they don't, it reports a @italic{signature violation} along with
test failures.  A signature violation does not stop the running
program.


@defform[(signature signature-form)]{

Returns the signature described by @racket[signature-form] as a value.
}

@subsection[#:tag "sludges-sig-forms"]{Signature Forms}

@nested{The student languages and @racketmodname[sludges] define
several signature forms that denote the most common atomic types
available in the student languages and its teachpacks.  They are
described in @secref["sl-predefined-signatures"] and in
@secref["sludges-sigs"] respectively.  }

@nested{Users can also define new signature types using the following
special forms:}

@defform/none[(input-signature-form ... -> output-signature-form)]{

Describes a function.  The inputs are described by the
@racket[input-signature-form]s and the output by
@racket[output-signature-form].

@racketblock[
(: double (Number -> Number))
(define (double x) (* 2 x))
]
}

@defform[(enum expr ...)]{

Describes an enumeration of specific values.

@racketblock[
(: cute? ((enum "cat" "snake") -> Boolean))
(define (cute? pet)
  (cond [(string=? pet "cat") #true]
        [(string=? pet "snake") #false]))
]
}

@defform[(mixed signature-form ...)]{

Describes mixed data (an itemization) where each case is described by
a @racket[signature-form].

@racketblock[
(define-type MaybeNumber (mixed Number Boolean))
]
}

@defform[(ListOf signature-form)]{

Describes a list whose elements are described by
@racket[signature-form].

@racketblock[
(: my-list (ListOf Number))
(define my-list (list 1 2 3))
]
}

@defform[(predicate expression)]{

Describes values through a predicate: @racket[expression] must
evaluate to a one-argument function returning a boolean.  The
signature matches all values for which the predicate returns
@racket[#true].

@racketblock[
(: x (predicate positive?))
(define x 42)
]
}


@subsection[#:tag "sl-predefined-signatures"]{Predefined Signatures}

@defthing[Any signature?]{
A signature for any value.
}

@defthing[Boolean signature?]{
A signature for booleans.
}

@defthing[Char signature?]{
A signature for characters (single-character strings).
}

@defproc[(ConsOf [first-sig signature?] [rest-sig signature?]) signature?]{
A signature for a @racket[cons] pair.
}

@defthing[EmptyList signature?]{
A signature for empty lists.
}

@defthing[False signature?]{
A signature for the Boolean value @racket[#false].
}

@defthing[Integer signature?]{
A signature for integer numbers.
}

@defthing[Rational signature?]{
A signature for rational numbers.
}

@defthing[Real signature?]{
A signature for real numbers.
}

@defthing[String signature?]{
A signature for strings.
}

@defthing[Symbol signature?]{
A signature for symbols.
}

@defthing[True signature?]{
A signature for the Boolean value @racket[#true].
}



@; ========================================
@section[#:tag "sludges-config"]{Configuration}

Module @racketmodname[sludges] includes two parameters that control how signature violations
are reported. They are documented in this section.

Signature violations are logged during execution, and reported at the
end together with test outcomes. Since it is common that several
violations have the same root cause, @racketmodname[sludges] does not
report all signature violations by default.  Instead, it groups them
into buckets according to the criterion
@racket[signature-violation-dedup], and only reports the first
@racket[max-signature-violations] in each bucket.

@defparam[max-signature-violations n (or/c exact-positive-integer? #f)
          #:value 1]{

Controls how many signature violations per bucket are shown before
further violations in the same bucket are ignored.

@itemlist[
  @item{@racket[1] (the default): only the first violation per
        bucket is shown.}
  @item{A positive integer @racket[n]: up to @racket[n] violations
        per bucket.}
  @item{@racket[#f]: no limit; all violations are shown.
        This is the original behavior in the student languages.}
]
}

@defparam[signature-violation-dedup mode symbol?
          #:value 'signature]{

Controls how signature violations are grouped into buckets.

@itemlist[
  @item{@racket['signature] (the default): one bucket per
        (@italic{signature name}, @italic{signature object}) pair.}
  @item{@racket['type-name]: one bucket per @italic{signature name}.
        This is the most coarse grouping criterion.}
  @item{@racket['object]: one bucket per
    (@italic{signature name}, @italic{violating object}) pair.}
]
}

Here is an example of how different grouping modes work:

@racketblock[
(max-signature-violations 1)

(define-type StringOrFalse (one-of String False))

(: S1 StringOrFalse)
(define S1 1)

(: S2 StringOrFalse)
(define S2 2)

(: S3 StringOrFalse)
(define S3 1)
]

@itemlist[
  @item{If @racket[signature-violation-dedup] is @racket['type-name], one
        signature violation (the first one, involving @racketidfont{S1}) is
        reported, because all violations are of the same @racket[StringOrFalse].}

  @item{If @racket[signature-violation-dedup] is @racket['signature], all
        three signature violations are reported, because each violates a
        different signature (defined with @racket[:]).}

  @item{If @racket[signature-violation-dedup] is @racket['object], two
        signature violations are reported. The third one (involving
        @racketidfont{S3}) is ignored because the value/object that violates
        @racketidfont{S3}'s signature is @racketidfont{1}, the same as the
        one that violates @racketidfont{S1}'s signature.}
]
