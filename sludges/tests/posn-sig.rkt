#lang racket/base

(require rackunit
         (only-in lang/private/teach
                  signature
                  Integer Natural Number String Boolean)
         (only-in lang/posn make-posn posn?)
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
;; Posn: non-parametric signature
;; ----------------------------------------

(define p1 (make-posn 3 4))

;; accepts posn instances (check-eq? for same object, check-equal? for fresh)
(check-eq? (say-no (apply-signature Posn p1)) p1)
(check-equal? (say-no (apply-signature Posn (make-posn 0 0))) (make-posn 0 0))

;; rejects non-posn values
(check-equal? (say-no (apply-signature Posn 42)) 'no)
(check-equal? (say-no (apply-signature Posn "hello")) 'no)
(check-equal? (say-no (apply-signature Posn #t)) 'no)
(check-equal? (say-no (apply-signature Posn (list 1 2))) 'no)

;; signature carries the name
(check-equal? (signature-name Posn) 'Posn)

;; ----------------------------------------
;; PosnOf: parametric signature
;; ----------------------------------------

(define IntPosn (PosnOf Integer Integer))

;; accepts posn with matching field types
(check-equal? (say-no (apply-signature IntPosn (make-posn 1 2))) (make-posn 1 2))
(check-equal? (say-no (apply-signature IntPosn (make-posn 0 -5))) (make-posn 0 -5))

;; rejects posn with wrong field types
(check-equal? (say-no (apply-signature IntPosn (make-posn "a" 2))) 'no)
(check-equal? (say-no (apply-signature IntPosn (make-posn 1 "b"))) 'no)
(check-equal? (say-no (apply-signature IntPosn (make-posn 1.5 2))) 'no)

;; rejects non-posn values entirely
(check-equal? (say-no (apply-signature IntPosn 42)) 'no)
(check-equal? (say-no (apply-signature IntPosn "hello")) 'no)

;; PosnOf with different field signatures
(define NumPosn (PosnOf Number Number))

(check-equal? (say-no (apply-signature NumPosn (make-posn 1.5 2.5))) (make-posn 1.5 2.5))
(check-equal? (say-no (apply-signature NumPosn (make-posn 1 2))) (make-posn 1 2))
(check-equal? (say-no (apply-signature NumPosn (make-posn "x" 2))) 'no)

;; PosnOf with heterogeneous field signatures
(define StrIntPosn (PosnOf String Integer))

(check-equal? (say-no (apply-signature StrIntPosn (make-posn "hello" 5)))
              (make-posn "hello" 5))
(check-equal? (say-no (apply-signature StrIntPosn (make-posn 1 2))) 'no)
(check-equal? (say-no (apply-signature StrIntPosn (make-posn "hello" "world"))) 'no)

;; PosnOf signature carries the name Posn
(check-equal? (signature-name IntPosn) 'Posn)
