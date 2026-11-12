#lang htdp/isl+

;; Fixture for ignore-types-report.rkt, which runs it with the teaching
;; languages' violation reporter installed.

(require sludges)

(: f (Number -> Number))
(define (f x) x)

(ignore-all-types)

(: g (Number -> Number))
(define (g x) x)

(check-expect (f "a") "a")
(check-expect (g "b") "b")
