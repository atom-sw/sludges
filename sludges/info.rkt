#lang info

(define name "sludges")

;; `dist/sludges.rkt` is a generated verbatim copy of `main.rkt`, kept only so
;; that it can be added manually as a teachpack in DrRacket.  Compiling it would
;; duplicate the whole build, and testing it would run the suite against a second
;; instance of the module.
(define compile-omit-paths '("dist"))

;; `examples/readme-examples.rkt` demonstrates signature violations, mirroring
;; the README.  A violation is reported rather than raised, so execution
;; continues into code the violating value cannot survive: the README's
;; `(first-person (cons "Homer" '()))` reports the Two+List violation and then
;; raises from `second`.  The file is therefore a demonstration that `raco test`
;; can only ever score as a failure, which is how it reached the package build
;; server's test-failure list.  It stays compiled, so errors in it are still
;; caught; it is only not a test.
(define test-omit-paths '("dist" "examples"))
