#lang racket/base

(require rackunit
         (only-in lang/private/teach
                  signature
                  Integer Natural Boolean String)
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
;; define-type with one-of (union)
;; ----------------------------------------

(define-type StringOrInteger (one-of String Integer))

(check-equal? (say-no (apply-signature StringOrInteger "hello")) "hello")
(check-equal? (say-no (apply-signature StringOrInteger 42)) 42)
(check-equal? (say-no (apply-signature StringOrInteger #t)) 'no)

;; ----------------------------------------
;; define-type with a bare signature
;; ----------------------------------------

(define-type MyInt Integer)

(check-equal? (say-no (apply-signature MyInt 5)) 5)
(check-equal? (say-no (apply-signature MyInt "x")) 'no)

;; ----------------------------------------
;; define-type carries the name
;; ----------------------------------------

(check-equal? (signature-name StringOrInteger) 'StringOrInteger)
(check-equal? (signature-name MyInt) 'MyInt)

;; ----------------------------------------
;; define-type with enum
;; ----------------------------------------

(define-type TrafficLight (enum "red" "yellow" "green"))

(check-equal? (say-no (apply-signature TrafficLight "red")) "red")
(check-equal? (say-no (apply-signature TrafficLight "yellow")) "yellow")
(check-equal? (say-no (apply-signature TrafficLight "green")) "green")
(check-equal? (say-no (apply-signature TrafficLight "blue")) 'no)

;; ----------------------------------------
;; define-type with combined (intersection)
;; ----------------------------------------

(define-type Octet (combined Integer
                             (predicate (lambda (x) (>= x 0)))
                             (predicate (lambda (x) (< x 256)))))

(check-equal? (say-no (apply-signature Octet 0)) 0)
(check-equal? (say-no (apply-signature Octet 255)) 255)
(check-equal? (say-no (apply-signature Octet -1)) 'no)
(check-equal? (say-no (apply-signature Octet 256)) 'no)
(check-equal? (say-no (apply-signature Octet 3.5)) 'no)

;; ----------------------------------------
;; define-type with function syntax (parametric, single parameter)
;; ----------------------------------------

(define-type (NumberGte v)
  (predicate (lambda (x) (and (number? x) (>= x v)))))

(check-equal? (say-no (apply-signature (NumberGte 0) 5)) 5)
(check-equal? (say-no (apply-signature (NumberGte 0) 0)) 0)
(check-equal? (say-no (apply-signature (NumberGte 0) -1)) 'no)
(check-equal? (say-no (apply-signature (NumberGte 10) 15)) 15)
(check-equal? (say-no (apply-signature (NumberGte 10) 5)) 'no)
(check-equal? (say-no (apply-signature (NumberGte 0) "hello")) 'no)

;; signature carries the constructor name
(check-equal? (signature-name (NumberGte 0)) 'NumberGte)

;; ----------------------------------------
;; define-type with function syntax (parametric, multiple parameters)
;; ----------------------------------------

(define-type (Between lo hi)
  (predicate (lambda (x) (and (number? x) (>= x lo) (<= x hi)))))

(check-equal? (say-no (apply-signature (Between 0 10) 5)) 5)
(check-equal? (say-no (apply-signature (Between 0 10) 0)) 0)
(check-equal? (say-no (apply-signature (Between 0 10) 10)) 10)
(check-equal? (say-no (apply-signature (Between 0 10) -1)) 'no)
(check-equal? (say-no (apply-signature (Between 0 10) 11)) 'no)
(check-equal? (say-no (apply-signature (Between 0 10) "x")) 'no)

(check-equal? (signature-name (Between 0 10)) 'Between)

;; ----------------------------------------
;; define-type with predicate (identifier argument)
;; ----------------------------------------
;; In racket/base, first-order->higher-order is a no-op (functions are
;; already first-class). These tests verify the predicate special case
;; works correctly in the normal (non-BSL) context.

(define-type EvenNumber (predicate even?))

(check-equal? (signature-name EvenNumber) 'EvenNumber)
(check-equal? (say-no (apply-signature EvenNumber 42)) 42)
(check-equal? (say-no (apply-signature EvenNumber 7)) 'no)
;; Note: (apply-signature EvenNumber "x") raises a contract error from
;; even? (expects integer), not a signature violation. This is expected
;; behavior: predicate signatures propagate the predicate's own errors.

(define-type PositiveNum (predicate positive?))

(check-equal? (signature-name PositiveNum) 'PositiveNum)
(check-equal? (say-no (apply-signature PositiveNum 5)) 5)
(check-equal? (say-no (apply-signature PositiveNum -3)) 'no)
(check-equal? (say-no (apply-signature PositiveNum 0)) 'no)
