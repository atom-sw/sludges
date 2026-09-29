#lang racket/base

;; Tests for the shadowed check-error, run the way DrRacket runs them.
;;
;; Under raco test, signature violations raise, so check-error catches them
;; anyway.  Teaching languages instead install report-signature-violation!,
;; which logs a violation and returns.  This file reproduces that setup: in a
;; fresh namespace it installs the reporter *before* sludges is instantiated
;; (sludges wraps whatever proc is current at that point), then loads
;; fixtures/isl-check-error.rkt and runs its tests.

(require rackunit
         racket/runtime-path)

(define-runtime-path fixture "fixtures/isl-check-error.rkt")

;; Run the fixture's tests; return the total number of tests, the number of
;; successful ones, the failed checks' reasons, and the logged violations'
;; messages.
(define-values (n-tests n-passed failures violations)
  (parameterize ([current-namespace (make-base-namespace)])
    (define (te name) (dynamic-require 'test-engine/test-engine name))
    ((dynamic-require 'deinprogramm/signature/signature 'signature-violation-proc)
     (dynamic-require 'test-engine/syntax 'report-signature-violation!))
    (dynamic-require fixture #f)
    (define to ((te 'run-tests!)))
    (values (length ((te 'test-object-tests) to))
            (length ((te 'test-object-successful-tests) to))
            (for/list ([f (reverse ((te 'test-object-failed-checks) to))])
              (let ([reason ((te 'failed-check-reason) f)])
                (list ((te 'expected-error?) reason)
                      (srcloc-line ((te 'fail-reason-srcloc) reason)))))
            (map (te 'signature-violation-message)
                 (reverse ((te 'test-object-signature-violations) to))))))

;; Every check passes except (check-error (zero 5)) on line 43, which
;; raises nothing and so fails with expected-error.
(check-equal? n-tests 9)
(check-equal? n-passed 8)
(check-equal? failures '((#t 43)))

;; Violations inside check-error are not logged; the one inside
;; check-expect still is.
(check-equal? violations '("expected a Number, but got \"b\""))
