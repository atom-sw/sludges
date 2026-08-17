;; The first three lines of this file were inserted by DrRacket. They record metadata
;; about the language level of this file in a form that our tools can easily process.
#reader(lib "htdp-beginner-reader.ss" "lang")((modname bsl-list-maybe) (read-case-sensitive #t) (teachpacks ((lib "sludges.rkt" "teachpack" "htdp"))) (htdp-settings #(#t constructor repeating-decimal #f #t none #f ((lib "sludges.rkt" "teachpack" "htdp")) #f)))

;; ----------------------------------------
;; List in BSL
;; ----------------------------------------

;; List accepts any list in a : declaration
(: sum-list (List -> Number))
(define (sum-list xs)
  (cond
    [(empty? xs) 0]
    [else (+ (first xs) (sum-list (rest xs)))]))

(check-expect (sum-list '()) 0)
(check-expect (sum-list (list 1 2 3)) 6)

;; List is a valid signature value
(check-expect (= 1 1) #true) ; placeholder to confirm module loads

;; ----------------------------------------
;; Maybe in BSL
;; ----------------------------------------

;; (Maybe Number) in a : declaration
(: safe-divide (Number Number -> (Maybe Number)))
(define (safe-divide a b)
  (if (= b 0)
      #false
      (/ a b)))

(check-expect (safe-divide 10 2) 5)
(check-expect (safe-divide 7 0) #false)

;; (Maybe String)
(: first-if-nonempty ((ListOf String) -> (Maybe String)))
(define (first-if-nonempty xs)
  (if (empty? xs) #false (first xs)))

(check-expect (first-if-nonempty '()) #false)
(check-expect (first-if-nonempty (list "hello" "world")) "hello")
