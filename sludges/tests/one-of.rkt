#lang racket/base

(require rackunit
         (only-in lang/private/teach
                  signature mixed
                  Integer Natural Boolean String)
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
;; one-of: basic accept / reject
;; ----------------------------------------

(define StringOrInteger (signature (one-of String Integer)))

;; accepts values that satisfy either constituent signature
(check-equal? (say-no (apply-signature StringOrInteger "hello")) "hello")
(check-equal? (say-no (apply-signature StringOrInteger 42)) 42)

;; rejects values that satisfy neither
(check-equal? (say-no (apply-signature StringOrInteger #t)) 'no)
(check-equal? (say-no (apply-signature StringOrInteger '())) 'no)

;; ----------------------------------------
;; one-of: more than two alternatives
;; ----------------------------------------

(define StringIntOrBool (signature (one-of String Integer Boolean)))

(check-equal? (say-no (apply-signature StringIntOrBool "hi")) "hi")
(check-equal? (say-no (apply-signature StringIntOrBool 7)) 7)
(check-equal? (say-no (apply-signature StringIntOrBool #f)) #f)
(check-equal? (say-no (apply-signature StringIntOrBool '())) 'no)

;; ----------------------------------------
;; one-of behaves identically to mixed
;; ----------------------------------------

(define StringOrInteger/mixed (signature (mixed String Integer)))

;; same values accepted
(check-equal? (say-no (apply-signature StringOrInteger/mixed "hello")) "hello")
(check-equal? (say-no (apply-signature StringOrInteger/mixed 42)) 42)

;; same values rejected
(check-equal? (say-no (apply-signature StringOrInteger/mixed #t)) 'no)
(check-equal? (say-no (apply-signature StringOrInteger/mixed '())) 'no)

;; ----------------------------------------
;; one-of: edge case with a single alternative
;; ----------------------------------------

(define JustNatural (signature (one-of Natural)))

(check-equal? (say-no (apply-signature JustNatural 0)) 0)
(check-equal? (say-no (apply-signature JustNatural 5)) 5)
(check-equal? (say-no (apply-signature JustNatural -1)) 'no)
(check-equal? (say-no (apply-signature JustNatural "x")) 'no)
