#lang info

(define name "sludges")

;; `dist/sludges.rkt` is a generated verbatim copy of `main.rkt`, kept only so
;; that it can be added manually as a teachpack in DrRacket.  Compiling it would
;; duplicate the whole build, and testing it would run the suite against a second
;; instance of the module.
(define compile-omit-paths '("dist"))
(define test-omit-paths '("dist"))
