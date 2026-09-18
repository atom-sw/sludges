;; The first three lines of this file were inserted by DrRacket. They record metadata
;; about the language level of this file in a form that our tools can easily process.
#reader(lib "htdp-beginner-reader.ss" "lang")((modname bsl-type-constructor) (read-case-sensitive #t) (teachpacks ((lib "sludges.rkt" "teachpack" "htdp"))) (htdp-settings #(#t constructor repeating-decimal #f #t none #f ((lib "sludges.rkt" "teachpack" "htdp")) #f)))

;; ----------------------------------------
;; define-type-constructor under BSL's first-order restriction
;; ----------------------------------------

;; cons?, first and rest are named as plain functions here.  BSL has no
;; first-class functions, so define-type-constructor lifts them with
;; first-order->higher-order before handing them to the signature machinery.
(define-type-constructor (Cons* first-sig rest-sig) cons? (first rest))

;; A list of numbers, defined by the recursion that describes it
(define-type NumList (one-of EmptyList (Cons* Number NumList)))

(: sum-nums (NumList -> Number))
(define (sum-nums xs)
  (cond
    [(empty? xs) 0]
    [else (+ (first xs) (sum-nums (rest xs)))]))

(check-expect (sum-nums '()) 0)
(check-expect (sum-nums (list 1 2 3)) 6)
(check-expect (sum-nums (list 10)) 10)

;; A list of strings, from the same constructor
(define-type StrList (one-of EmptyList (Cons* String StrList)))

(: join-all (StrList -> String))
(define (join-all xs)
  (cond
    [(empty? xs) ""]
    [else (string-append (first xs) (join-all (rest xs)))]))

(check-expect (join-all '()) "")
(check-expect (join-all (list "a" "b" "c")) "abc")

;; ----------------------------------------
;; Add1 in BSL
;; ----------------------------------------

;; The genuinely recursive definition of the natural numbers
(define-type Nat (one-of (enum 0) (Add1 Nat)))

(: count-down (Nat -> Number))
(define (count-down n)
  (cond
    [(= n 0) 0]
    [else (+ 1 (count-down (sub1 n)))]))

(check-expect (count-down 0) 0)
(check-expect (count-down 5) 5)

;; (Add1 T) is add1 restricted to the naturals, so (Add1 Integer) describes
;; the positive integers.
(define-type Positive (Add1 Integer))

(: halve (Positive -> Number))
(define (halve n) (/ n 2))

(check-expect (halve 4) 2)
(check-expect (halve 1) 1/2)

;; A parametric type built on a lifted constructor
(define-type (ListOf* T) (one-of EmptyList (Cons* T (ListOf* T))))

(: length* ((ListOf* Number) -> Nat))
(define (length* xs)
  (cond
    [(empty? xs) 0]
    [else (add1 (length* (rest xs)))]))

(check-expect (length* '()) 0)
(check-expect (length* (list 1 2 3)) 3)

;; ----------------------------------------
;; Cons in BSL
;; ----------------------------------------

;; Cons is the capitalized spelling of cons, and an alias of ConsOf
(define-type SymList (one-of EmptyList (Cons Symbol SymList)))

(: count-syms (SymList -> Nat))
(define (count-syms xs)
  (cond
    [(empty? xs) 0]
    [else (add1 (count-syms (rest xs)))]))

(check-expect (count-syms '()) 0)
(check-expect (count-syms (list 'a 'b 'c)) 3)

;; the two spellings are interchangeable, including within one definition
(define-type Two+Str (one-of (Cons String (ConsOf String EmptyList))
                             (ConsOf String Two+Str)))

(: first-two (Two+Str -> String))
(define (first-two xs) (string-append (first xs) (second xs)))

(check-expect (first-two (list "a" "b")) "ab")
(check-expect (first-two (list "a" "b" "c")) "ab")
