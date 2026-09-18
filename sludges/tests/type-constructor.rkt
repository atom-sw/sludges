#lang racket/base

(require rackunit
         (only-in lang/private/teach
                  signature
                  Integer String Any EmptyList ConsOf)
         deinprogramm/signature/signature
         sludges)

;; say-no: evaluate body; if a signature violation occurs, return 'no
;; instead of raising an error. Otherwise return the result.
(define-syntax say-no
  (syntax-rules ()
    ((_ ?body ...)
     (let/ec exit
       (call-with-signature-violation-proc
        (lambda (obj signature message blame)
          (exit 'no))
        (lambda ()
          ?body ...))))))

;; ----------------------------------------
;; define-type-constructor: lifting cons
;; ----------------------------------------

;; pair? recognizes the values cons builds; car and cdr take them apart.
(define-type-constructor (Cons* first-sig rest-sig) pair? (car cdr))

(define-type AnyList (one-of EmptyList (Cons* Any AnyList)))

(check-equal? (say-no (apply-signature AnyList '())) '())
(check-equal? (say-no (apply-signature AnyList '(1 2 3))) '(1 2 3))
(check-equal? (say-no (apply-signature AnyList 5)) 'no)
(check-equal? (say-no (apply-signature AnyList "x")) 'no)

;; an improper list is not built by the EmptyList / Cons* recursion
(check-equal? (say-no (apply-signature AnyList (cons 1 2))) 'no)

;; the element signature is enforced too
(define-type IntList (one-of EmptyList (Cons* Integer IntList)))

(check-equal? (say-no (apply-signature IntList '(1 2 3))) '(1 2 3))
(check-equal? (say-no (apply-signature IntList '())) '())
(check-equal? (say-no (apply-signature IntList (list 1 "x" 3))) 'no)

;; a lifted constructor carries its name
(check-equal? (signature-name (Cons* Any Any)) 'Cons*)

;; ----------------------------------------
;; Lifted constructors in a multi-depth mixed form
;; ----------------------------------------

;; The shape that fold-consof-prefixes exists to normalize for ConsOf.  A
;; lifted constructor builds combined signatures rather than lazy wraps, so
;; DeinProgramm's mixed normalization never sees it and the form works as is.
(define-type Two+List (one-of (Cons* String (Cons* String EmptyList))
                              (Cons* String Two+List)))

(check-equal? (say-no (apply-signature Two+List '("a" "b"))) '("a" "b"))
(check-equal? (say-no (apply-signature Two+List '("a" "b" "c"))) '("a" "b" "c"))
(check-equal? (say-no (apply-signature Two+List (list "a" 1))) 'no)
(check-equal? (say-no (apply-signature Two+List 5)) 'no)

;; ----------------------------------------
;; Add1: the natural numbers by recursion
;; ----------------------------------------

(define-type Natural* (one-of (enum 0) (Add1 Natural*)))

(check-equal? (say-no (apply-signature Natural* 0)) 0)
(check-equal? (say-no (apply-signature Natural* 1)) 1)
(check-equal? (say-no (apply-signature Natural* 42)) 42)
(check-equal? (say-no (apply-signature Natural* -1)) 'no)
(check-equal? (say-no (apply-signature Natural* 1.5)) 'no)
(check-equal? (say-no (apply-signature Natural* "x")) 'no)

;; Add1 restricts to positive exact integers, which is what makes the
;; recursion above well founded: (Add1 Integer) is the positive integers.
(define-type Positive (Add1 Integer))

(check-equal? (say-no (apply-signature Positive 1)) 1)
(check-equal? (say-no (apply-signature Positive 7)) 7)
(check-equal? (say-no (apply-signature Positive 0)) 'no)
(check-equal? (say-no (apply-signature Positive -3)) 'no)
(check-equal? (say-no (apply-signature Positive 2.5)) 'no)

;; Add1 is deliberately narrower than add1, which accepts -5 and 1.5 alike.
;; A faithful lift is impossible: checking v against (Add1 T) checks sub1(v)
;; against T, so a recursive type descends by sub1 until it reaches its base
;; case, and nothing in Add1 can see where that base case is.  Admitting every
;; number add1 accepts would make Natural* run forever on -1 rather than
;; reject it.  These tests pin the boundary the documentation promises.

;; Inexact integers are out, so the recursive Natural* differs from
;; (integer-from 0), which accepts them.
(define-type NaturalI (integer-from 0))

(check-equal? (say-no (apply-signature Natural* 2.0)) 'no)
(check-equal? (say-no (apply-signature Natural* 0.0)) 'no)
(check-equal? (say-no (apply-signature NaturalI 2.0)) 2.0)

;; Every base case at or above zero works, nested ones included.
(define-type PositiveBase (one-of (enum 1) (Add1 PositiveBase)))

(check-equal? (say-no (apply-signature PositiveBase 1)) 1)
(check-equal? (say-no (apply-signature PositiveBase 4)) 4)
(check-equal? (say-no (apply-signature PositiveBase 0)) 'no)
(check-equal? (say-no (apply-signature PositiveBase -1)) 'no)

(define-type EvenNat (one-of (enum 0) (Add1 (Add1 EvenNat))))

(check-equal? (say-no (apply-signature EvenNat 0)) 0)
(check-equal? (say-no (apply-signature EvenNat 4)) 4)
(check-equal? (say-no (apply-signature EvenNat 1)) 'no)
(check-equal? (say-no (apply-signature EvenNat 5)) 'no)

;; A negative base case does not work: this is the documented limit, not a
;; property to rely on.  -4, -1, 0 and 3 belong to the set it describes, and
;; Add1 rejects them rather than descending past zero forever.
(define-type FromNegative (one-of (enum -5) (Add1 FromNegative)))

(check-equal? (say-no (apply-signature FromNegative -5)) -5)
(check-equal? (say-no (apply-signature FromNegative -4)) 'no)
(check-equal? (say-no (apply-signature FromNegative 0)) 'no)

;; ----------------------------------------
;; Arity
;; ----------------------------------------

;; A lifted constructor takes exactly one type argument per selector.
(check-exn exn:fail:contract:arity? (lambda () (Cons* Integer)))
(check-exn exn:fail:contract:arity? (lambda () (Add1 Integer Integer)))

;; ----------------------------------------
;; Recursion through and between definitions
;; ----------------------------------------

;; A type may refer forward to a constructor defined further down.
(define-type FwdList (one-of EmptyList (Late Any FwdList)))
(define-type-constructor (Late a d) pair? (car cdr))

(check-equal? (say-no (apply-signature FwdList '(1 2))) '(1 2))
(check-equal? (say-no (apply-signature FwdList 5)) 'no)

;; Mutually recursive types built on Add1.
(define-type Odd* (one-of (enum 1) (Add1 Even*)))
(define-type Even* (one-of (enum 0) (Add1 Odd*)))

(check-equal? (say-no (apply-signature Even* 2)) 2)
(check-equal? (say-no (apply-signature Even* 3)) 'no)
(check-equal? (say-no (apply-signature Odd* 3)) 3)
(check-equal? (say-no (apply-signature Odd* 2)) 'no)
(check-equal? (say-no (apply-signature Even* -1)) 'no)

;; A recursive parametric type, whose recursive reference is itself a call
;; form: the definition-time probe must not re-enter it.
(define-type (ListOf* T) (one-of EmptyList (Cons* T (ListOf* T))))

(check-equal? (say-no (apply-signature (ListOf* Integer) '(1 2))) '(1 2))
(check-equal? (say-no (apply-signature (ListOf* Integer) (list 1 "x"))) 'no)
(check-equal? (say-no (apply-signature (ListOf* String) '("a"))) '("a"))

;; ----------------------------------------
;; Heads that are not type constructors
;; ----------------------------------------

;; cons and add1 are ordinary functions, not functions from signatures to a
;; signature.  parse-signature accepts them and delays the call, so without a
;; check they would fail deep inside DeinProgramm on first use.  define-type
;; reports them when the definition is evaluated.

(define-syntax-rule (check-bad-head ?rx ?body)
  (check-exn ?rx (lambda () (let () ?body (void)))))

(check-bad-head #rx"add1 is not a type constructor"
  (define-type N1 (one-of (enum 0) (add1 N1))))
(check-bad-head #rx"in the definition of N1"
  (define-type N1 (one-of (enum 0) (add1 N1))))
(check-bad-head #rx"use Add1 instead"
  (define-type N1 (one-of (enum 0) (add1 N1))))

(check-bad-head #rx"cons is not a type constructor"
  (define-type L1 (one-of EmptyList (cons Any L1))))
(check-bad-head #rx"use Cons instead"
  (define-type L1 (one-of EmptyList (cons Any L1))))

(check-bad-head #rx"list is not a type constructor"
  (define-type L2 (one-of EmptyList (list Any))))
(check-bad-head #rx"use ListOf instead"
  (define-type L2 (one-of EmptyList (list Any))))

;; A genuine type constructor passes the check untouched.
(define-type Good (one-of EmptyList (ConsOf Any Good)))
(check-equal? (say-no (apply-signature Good '(1 2))) '(1 2))
(check-equal? (say-no (apply-signature Good 5)) 'no)

;; Procedure signatures are not applications: their head is an argument type.
(define-type IntToInt (Integer -> Integer))
(check-true (procedure? (say-no (apply-signature IntToInt add1))))

;; predicate bodies are user expressions and are left alone.
(define-type Even? (predicate even?))
(check-equal? (say-no (apply-signature Even? 4)) 4)
(check-equal? (say-no (apply-signature Even? 5)) 'no)

;; ----------------------------------------
;; Cons: the capitalized spelling of cons
;; ----------------------------------------
;; A function lifted to a type constructor keeps its name, capitalized, as
;; add1 becomes Add1.  Cons is that name for cons, and is ConsOf itself.

(check-eq? Cons ConsOf)

(define-type ConsList (one-of EmptyList (Cons Any ConsList)))

(check-equal? (say-no (apply-signature ConsList '())) '())
(check-equal? (say-no (apply-signature ConsList '(1 2 3))) '(1 2 3))
(check-equal? (say-no (apply-signature ConsList 5)) 'no)
(check-equal? (say-no (apply-signature ConsList (cons 1 2))) 'no)

(define-type ConsInts (one-of EmptyList (Cons Integer ConsInts)))

(check-equal? (say-no (apply-signature ConsInts '(1 2 3))) '(1 2 3))
(check-equal? (say-no (apply-signature ConsInts (list 1 "x"))) 'no)

;; lowercase cons is still reported, and the suggestion is now just the
;; capitalization of what was written
(check-bad-head #rx"cons is not a type constructor.*use Cons instead"
  (define-type L3 (one-of EmptyList (cons Any L3))))
