#lang racket/base

(require rackunit
         (only-in lang/private/teach
                  signature
                  Integer Natural Boolean Number String)
         deinprogramm/signature/signature
         sludges)

;; say-no: evaluate body; if a signature violation occurs, return 'no
;; instead of raising an error. Otherwise return the result.
(define-syntax say-no
  (syntax-rules ()
    ((_ ?body ...)
     (let/ec exit
       (call-with-signature-violation-proc
        (lambda (obj signature message blame)
          (exit 'no))
        (lambda ()
          ?body ...))))))

;; ----------------------------------------
;; Vector: any vector
;; ----------------------------------------

(check-equal? (say-no (apply-signature Vector (vector))) (vector))
(check-equal? (say-no (apply-signature Vector (vector 1 2 3))) (vector 1 2 3))
(check-equal? (say-no (apply-signature Vector (vector "a" #t 42))) (vector "a" #t 42))

;; Rejects non-vectors
(check-equal? (say-no (apply-signature Vector 42)) 'no)
(check-equal? (say-no (apply-signature Vector "hello")) 'no)
(check-equal? (say-no (apply-signature Vector '(1 2 3))) 'no)
(check-equal? (say-no (apply-signature Vector #f)) 'no)

;; Name is preserved
(check-equal? (signature-name Vector) 'Vector)

;; ----------------------------------------
;; VectorOf: vector with typed elements
;; ----------------------------------------

;; (VectorOf Number): accepts vectors of numbers
(check-equal? (say-no (apply-signature (VectorOf Number) (vector 1 2 3))) (vector 1 2 3))
(check-equal? (say-no (apply-signature (VectorOf Number) (vector -1.5 0 42))) (vector -1.5 0 42))
(check-equal? (say-no (apply-signature (VectorOf Number) (vector))) (vector))

;; Rejects vectors with wrong element types
(check-equal? (say-no (apply-signature (VectorOf Number) (vector "a" "b"))) 'no)
(check-equal? (say-no (apply-signature (VectorOf Number) (vector 1 "x"))) 'no)

;; Rejects non-vectors entirely
(check-equal? (say-no (apply-signature (VectorOf Number) '(1 2 3))) 'no)
(check-equal? (say-no (apply-signature (VectorOf Number) 42)) 'no)

;; (VectorOf String)
(check-equal? (say-no (apply-signature (VectorOf String) (vector "a" "b"))) (vector "a" "b"))
(check-equal? (say-no (apply-signature (VectorOf String) (vector 1 2))) 'no)

;; (VectorOf Boolean)
(check-equal? (say-no (apply-signature (VectorOf Boolean) (vector #t #f #t))) (vector #t #f #t))
(check-equal? (say-no (apply-signature (VectorOf Boolean) (vector #t 0))) 'no)

;; Name is preserved regardless of argument
(check-equal? (signature-name (VectorOf Number)) 'VectorOf)
(check-equal? (signature-name (VectorOf String)) 'VectorOf)
