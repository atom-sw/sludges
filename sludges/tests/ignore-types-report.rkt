#lang racket/base

;; Tests for ignore-types and ignore-all-types, run the way DrRacket runs
;; them: with the teaching languages' reporter, which logs a violation and
;; continues instead of raising.  See check-error-report.rkt for the setup.

(require rackunit
         racket/runtime-path)

(define-runtime-path ignore-types-fixture "fixtures/isl-ignore-types-report.rkt")
(define-runtime-path ignore-all-types-fixture "fixtures/isl-ignore-all-types-report.rkt")

;; Run a fixture's tests in a fresh namespace; return the number of tests
;; that passed and the messages of the logged violations.
(define (run fixture)
  (parameterize ([current-namespace (make-base-namespace)])
    (define (te name) (dynamic-require 'test-engine/test-engine name))
    ((dynamic-require 'deinprogramm/signature/signature 'signature-violation-proc)
     (dynamic-require 'test-engine/syntax 'report-signature-violation!))
    (dynamic-require fixture #f)
    (define to ((te 'run-tests!)))
    (values (length ((te 'test-object-successful-tests) to))
            (map (te 'signature-violation-message)
                 (reverse ((te 'test-object-signature-violations) to))))))

;; Only the call outside ignore-types is checked.
(let-values ([(passed violations) (run ignore-types-fixture)])
  (check-equal? passed 2)
  (check-equal? violations '("expected a Number, but got \"outside\"")))

;; After ignore-all-types, nothing is checked, not even the function
;; defined before it.
(let-values ([(passed violations) (run ignore-all-types-fixture)])
  (check-equal? passed 2)
  (check-equal? violations '()))
