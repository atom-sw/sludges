;; The first three lines of this file were inserted by DrRacket. They record metadata
;; about the language level of this file in a form that our tools can easily process.
#reader(lib "htdp-beginner-reader.ss" "lang")((modname bsl-header-template) (read-case-sensitive #t) (teachpacks ((lib "sludges.rkt" "teachpack" "htdp"))) (htdp-settings #(#t constructor repeating-decimal #f #t none #f ((lib "sludges.rkt" "teachpack" "htdp")) #f)))

;; ----------------------------------------
;; define-header and define-template in BSL
;; ----------------------------------------

;; Full design recipe: header, template, implementation
(: count (List -> Number))
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

;; Template and implementation (no header)
(define-template (add1-to-all lst)
  (cond
    [(empty? lst) ...]
    [(cons? lst) (... (first lst) ... (add1-to-all (rest lst)) ...)]))
(define (add1-to-all lst)
  (cond
    [(empty? lst) '()]
    [(cons? lst) (cons (+ 1 (first lst)) (add1-to-all (rest lst)))]))

(check-expect (add1-to-all '()) '())
(check-expect (add1-to-all (list 1 2 3)) (list 2 3 4))

;; Multiple-argument function
(: my-max (Number Number -> Number))
(define-header (my-max a b) 0)
(define-template (my-max a b) (... a ... b ...))
(define (my-max a b) (if (> a b) a b))

(check-expect (my-max 3 7) 7)
(check-expect (my-max 10 2) 10)
