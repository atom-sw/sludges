;; The first three lines of this file were inserted by DrRacket. They record metadata
;; about the language level of this file in a form that our tools can easily process.
#reader(lib "htdp-advanced-reader.ss" "lang")((modname asl-vector) (read-case-sensitive #t) (teachpacks ((lib "sludges.rkt" "teachpack" "htdp"))) (htdp-settings #(#t constructor repeating-decimal #f #t none #f ((lib "sludges.rkt" "teachpack" "htdp")) #f)))

;; ----------------------------------------
;; Vector in ASL
;; ----------------------------------------

(: make-zero-vector (Natural -> Vector))
(define (make-zero-vector n)
  (make-vector n 0))

(check-expect (make-zero-vector 0) (vector))
(check-expect (make-zero-vector 3) (vector 0 0 0))

;; ----------------------------------------
;; VectorOf in ASL
;; ----------------------------------------

(: vector-sum ((VectorOf Number) -> Number))
(define (vector-sum v)
  (local [(define (loop i acc)
            (if (= i (vector-length v))
                acc
                (loop (+ i 1) (+ acc (vector-ref v i)))))]
    (loop 0 0)))

(check-expect (vector-sum (vector)) 0)
(check-expect (vector-sum (vector 1 2 3)) 6)
(check-expect (vector-sum (vector -1 4 -2)) 1)

(: vector-append-string ((VectorOf String) -> String))
(define (vector-append-string v)
  (apply string-append (vector->list v)))

(check-expect (vector-append-string (vector)) "")
(check-expect (vector-append-string (vector "hello" " " "world")) "hello world")
