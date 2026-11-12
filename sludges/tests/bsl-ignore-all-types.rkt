#lang htdp/bsl

;; Tests for ignore-all-types: after it, no signature is checked, in
;; functions defined before or after it, in struct fields, and in tests.
;; Under raco test a violation raises, so each check-expect below passes
;; only because nothing is checked.

(require sludges)

(: before (Number -> Number))
(define (before x) x)

(ignore-all-types)

(define-type Natural+ (one-of (enum 1) (Add1 Natural+)))
(define-type Age (integer-from 0))
(define-struct person [(name String) (age Age)])

(: after (Natural+ -> Natural+))
(define (after n) n)

(check-expect (before "a") "a")
(check-expect (after -5) -5)
(check-expect (after 100000000) 100000000)
(check-expect (person-age (make-person "Maggie" -1)) -1)
(check-expect (ignore-types (after 0)) 0)
