#lang htdp/isl

;; Fixture for check-error-report.rkt, which runs it with the teaching
;; languages' violation reporter installed.  Not a test on its own: under
;; raco test, violations raise anyway, and one check here fails on purpose.

(require sludges)

(define-type CSList
  (one-of
   (Cons Any EmptyList)
   (Cons Number CSList)
   (Cons String CSList)))

(: cs (CSList -> Any))
(define (cs lst)
  (cond
    [(and (empty? (rest lst)) (string? (first lst)))
     (string->number (first lst))]
    [(empty? (rest lst))
     (first lst)]
    [(number? (first lst))
     (+ 1 (cs (rest lst)))]
    [(string? (first lst))
     (cs (rest lst))]))

;; The body would crash on these values after the violation, too.
(check-error (cs '()))
(check-error (cs (list #true 12)))
(check-error (cs (list 7 (make-posn 1 2) 1)))

(: zero (Number -> Number))
(define (zero x) 0)

;; The body returns normally: only the violation makes these pass.
(check-error (zero "a"))
(check-error (zero "a") "expected a Number, but got \"a\"")

;; A genuine error still passes.
(check-error (/ 1 0))

;; No error: must still fail.
(check-error (zero 5))

;; Outside check-error, the violation is still reported and execution continues.
(check-expect (zero "b") 0)

(check-expect (cs (list 7 "3")) 4)
