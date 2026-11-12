#lang htdp/isl+

;; Fixture for isl-ignore-all-types.rkt: a library that switches the checks
;; off for the whole program, including the files that require it.

(require sludges)

(ignore-all-types)

(: lib-id (Number -> Number))
(define (lib-id x) x)

(provide lib-id)
