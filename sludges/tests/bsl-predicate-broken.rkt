#lang racket/base

;; Test that (signature (predicate f)) is broken in BSL when f is a
;; first-order-wrapped function (like even?). This demonstrates the
;; problem that define-type's predicate special case fixes.
;;
;; We compile a BSL program that uses bare (signature (predicate even?))
;; and verify it fails with the expected error message.

(require rackunit
         racket/file)

;; Helper: try to compile a string as a BSL program, return #f if it
;; succeeds or the exn message string if it fails.
(define (bsl-compile-error prog-string)
  (define tmp (make-temporary-file "bsl-test-~a.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file tmp
        (lambda (out) (write-string prog-string out))
        #:exists 'truncate)
      (with-handlers ([exn:fail? (lambda (e) (exn-message e))])
        (dynamic-require tmp #f)
        #f))
    (lambda ()
      (delete-file tmp))))

;; ----------------------------------------
;; (signature (predicate even?)) fails in BSL
;; ----------------------------------------

(define broken-prog
  (string-append
   "#lang htdp/bsl\n"
   "(define EvenNum (signature (predicate even?)))\n"))

(define result (bsl-compile-error broken-prog))

;; It should fail (result is a string, not #f)
(check-not-false result
  "expected (signature (predicate even?)) to fail in BSL")

;; The error message should mention the first-order restriction
(check-regexp-match
 #rx"expected a function call"
 result)
