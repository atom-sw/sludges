#lang htdp/isl+

;; Tests for provide, re-exported by sludges: a program split over two
;; files keeps its signatures and their checks across the module boundary.
;; Under raco test a violation raises, so check-error detects it.

(require sludges)
(require "fixtures/isl-provide-lib.rkt")

;; The library's signatures work in this module's own declarations.
(: older? (Person Person -> Boolean))
(define (older? a b) (> (person-age a) (person-age b)))

(: ages ((ListOf Person) -> (ListOf Age)))
(define (ages ps) (map person-age ps))

(: name-of (Person -> String))
(define (name-of p) "someone")

(: homer (PersonOf String Age))
(define homer (make-person "Homer" 39))

(check-expect (older? homer (make-person "Bart" 10)) #true)
(check-expect (ages (list homer)) (list 39))
(check-expect (birthday homer) (make-person "Homer" 40))
(check-expect (person? homer) #true)

;; The library's checks fire on values from this module.
(check-error (make-person "Maggie" -1))
(check-error (birthday 5))
(check-error (name-of 5))
