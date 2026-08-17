;; The first three lines of this file were inserted by DrRacket. They record metadata
;; about the language level of this file in a form that our tools can easily process.
#reader(lib "htdp-beginner-reader.ss" "lang")((modname readme-examples) (read-case-sensitive #t) (teachpacks ((lib "sludges.rkt" "teachpack" "htdp"))) (htdp-settings #(#t constructor repeating-decimal #f #t none #f ((lib "sludges.rkt" "teachpack" "htdp")) #f)))
; data type Person corresponds to all instances of this struct
; where both fields are a String
(define-struct person [(first String) (last String)])

; recursive data type definition: lists of Strings with two or more elements
(define-type Two+List (one-of
                       (ConsOf String (ConsOf String EmptyList))
                       (ConsOf String Two+List)))

; typed signature of function first-person
(: first-person (Two+List -> Person))
(define (first-person lst)
  (make-person (first lst) (second lst)))

; expected a String, but got 'Simpson
(make-person "Homer" 'Simpson)

; expected a Two+List, but got (cons "Homer" '())
(first-person (cons "Homer" '()))

(define-type Even (predicate even?))
(: d2 (Even -> Number))
(define (d2 n) (/ n 2))

(check-expect (d2 7) 3)
