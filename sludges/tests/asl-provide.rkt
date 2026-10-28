#lang htdp/asl

;; Tests for provide, re-exported by sludges, in ASL: a program split over
;; two files keeps its signatures and their checks across the module
;; boundary, and the library's structs keep their setters.
;; Under raco test a violation raises, so check-error detects it.

(require sludges)
(require "fixtures/asl-provide-lib.rkt")

(: older? (Person Person -> Boolean))
(define (older? a b) (> (person-age a) (person-age b)))

(: homer (PersonOf String Age))
(define homer (make-person "Homer" 39))

(define bart (make-person "Bart" 10))
(set-age! bart 11)

(check-expect (older? homer bart) #true)
(check-expect (birthday homer) (make-person "Homer" 40))
(check-expect (person-age bart) 11)

(check-error (make-person "Maggie" -1))
(check-error (birthday 5))
(check-error (set-age! bart -5))
