;; The first three lines of this file were inserted by DrRacket. They record metadata
;; about the language level of this file in a form that our tools can easily process.
#reader(lib "htdp-intermediate-lambda-reader.ss" "lang")((modname isl-header-template) (read-case-sensitive #t) (teachpacks ((lib "sludges.rkt" "teachpack" "htdp"))) (htdp-settings #(#t constructor repeating-decimal #f #t none #f ((lib "sludges.rkt" "teachpack" "htdp")) #f)))

;; ----------------------------------------
;; define-header and define-template in ISL+
;; ----------------------------------------

;; Full design recipe: header, template, implementation
(: count (List -> Natural))
(define-header (count lst) 0)
(define-template (count lst)
  (cond
    [(empty? lst) ...]
    [(cons? lst) (... (first lst) ... (count (rest lst)) ...)]))
(define (count lst)
  (cond
    [(empty? lst) 0]
    [(cons? lst) (+ 1 (count (rest lst)))]))

(check-expect (count '()) 0)
(check-expect (count (list 1 2 3)) 3)

;; Header and implementation (no template)
(: double (Number -> Number))
(define-header (double n) 0)
(define (double n) (* 2 n))

(check-expect (double 5) 10)

;; Using lambda in ISL+
(: negate (Number -> Number))
(define-header (negate x) 0)
(define-template (negate x) (... x ...))
(define negate (lambda (x) (- x)))

(check-expect (negate 5) -5)
(check-expect (negate -3) 3)

;; Higher-order function
(: apply-twice ((Number -> Number) Number -> Number))
(define-header (apply-twice f x) 0)
(define-template (apply-twice f x) (... (f ...) ...))
(define (apply-twice f x) (f (f x)))

(check-expect (apply-twice add1 5) 7)
(check-expect (apply-twice sqr 2) 16)
