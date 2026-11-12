#lang htdp/isl+

;; Fixture for ignore-types-report.rkt, which runs it with the teaching
;; languages' violation reporter installed.  Not a test on its own: under
;; raco test, the violation outside ignore-types raises.

(require sludges)

(: checked (Number -> Number))
(define (checked x) x)

(: unchecked (Number -> Number))
(define (unchecked x) x)

(check-expect (checked "outside") "outside")
(check-expect (ignore-types (unchecked "inside")) "inside")
