#lang htdp/bsl

;; Test that define-type with predicate works in BSL,
;; where functions are first-order (not usable as values).
;;
;; Without the first-order->higher-order fix in define-type,
;; (signature (predicate even?)) would fail in BSL with:
;;   "expected a function call, but there is no open parenthesis
;;    before this function"
;;
;; define-type applies first-order->higher-order to unwrap the
;; first-order restriction before passing to signature.

(require sludges)

;; ----------------------------------------
;; define-type with a built-in predicate
;; ----------------------------------------

(define-type EvenNum (predicate even?))

(: x EvenNum)
(define x 42)

(check-expect x 42)
(check-expect (even? x) #true)

;; ----------------------------------------
;; define-type with a student-defined predicate
;; ----------------------------------------

(define (my-even? n) (= (remainder n 2) 0))

(define-type MyEven (predicate my-even?))

(: y MyEven)
(define y 100)

(check-expect y 100)

;; ----------------------------------------
;; define-type with other signature forms still works
;; ----------------------------------------

(define-type TrafficLight (enum "red" "yellow" "green"))

(: light TrafficLight)
(define light "red")

(check-expect light "red")

;; ----------------------------------------
;; one-of works in BSL too
;; ----------------------------------------

(define-type StringOrNum (one-of String Integer))

(: a StringOrNum)
(define a "hello")

(: b StringOrNum)
(define b 42)

(check-expect a "hello")
(check-expect b 42)
