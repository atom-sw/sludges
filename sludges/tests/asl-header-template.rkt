;; The first three lines of this file were inserted by DrRacket. They record metadata
;; about the language level of this file in a form that our tools can easily process.
#reader(lib "htdp-advanced-reader.ss" "lang")((modname asl-header-template) (read-case-sensitive #t) (teachpacks ((lib "sludges.rkt" "teachpack" "htdp"))) (htdp-settings #(#t constructor repeating-decimal #f #t none #f ((lib "sludges.rkt" "teachpack" "htdp")) #f)))

;; ----------------------------------------
;; define-header and define-template in ASL
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
(: square (Number -> Number))
(define-header (square n) 0)
(define (square n) (* n n))

(check-expect (square 5) 25)

;; Using begin in ASL
(: greet (String -> String))
(define-header (greet name) "")
(define-template (greet name) (... name ...))
(define (greet name) (string-append "Hello, " name "!"))

(check-expect (greet "World") "Hello, World!")
