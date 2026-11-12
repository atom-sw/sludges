#lang htdp/isl+

;; Tests for ignore-types: the expression runs without signature checks,
;; while the rest of the program keeps them.  Under raco test a violation
;; raises, so a check-expect that passes on a bad value shows that nothing
;; was checked, and check-error shows that a check still fires.

(require sludges)

;; Checking n against this type descends n levels, so a check of a large
;; number runs out of memory.
(define-type Natural+ (one-of (enum 1) (Add1 Natural+)))
(define-type Age (integer-from 0))
(define-struct person [(name String) (age Age)])

(: id (Natural+ -> Natural+))
(define (id n) n)

;; No checks inside: neither a bad argument, nor a bad struct field, nor
;; the check of a number far too large to check.
(check-expect (ignore-types (id -5)) -5)
(check-expect (ignore-types (person-age (make-person "Maggie" -1))) -1)
(check-expect (ignore-types (id 100000000)) 100000000)

;; ignore-types returns the value of its expression, and works inside a
;; function, for the duration of each call.
(: id-unchecked (Any -> Any))
(define (id-unchecked x) (ignore-types (id x)))
(check-expect (id-unchecked 0) 0)

;; Checks still fire outside it.
(check-error (id -5))
(check-error (make-person "Maggie" -1))

;; It covers the evaluation of the expression, not the values it returns:
;; a function created inside and called later is checked again.
(define escaped (ignore-types (lambda (x) (id x))))
(check-error (escaped -7))
