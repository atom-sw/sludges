#lang htdp/isl+

;; Tests for ignore-all-types across files: a required library switched the
;; checks off, so this file's own signatures go unchecked too.

(require sludges)
(require "fixtures/isl-ignore-all-types-lib.rkt")

(: own (String -> String))
(define (own s) s)

(check-expect (lib-id "a") "a")
(check-expect (own 5) 5)
