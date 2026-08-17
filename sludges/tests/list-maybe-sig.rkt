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
;; List: synonym for (ListOf Any)
;; ----------------------------------------

;; Accepts any list regardless of element types
(check-equal? (say-no (apply-signature List '())) '())
(check-equal? (say-no (apply-signature List (list 1 2 3))) (list 1 2 3))
(check-equal? (say-no (apply-signature List (list "a" #t 42))) (list "a" #t 42))
(check-equal? (say-no (apply-signature List (list (list 1) (list 2)))) (list (list 1) (list 2)))

;; Rejects non-lists
(check-equal? (say-no (apply-signature List 42)) 'no)
(check-equal? (say-no (apply-signature List "hello")) 'no)
(check-equal? (say-no (apply-signature List #t)) 'no)
(check-equal? (say-no (apply-signature List (cons 1 2))) 'no) ; improper list

;; Name is preserved
(check-equal? (signature-name List) 'List)

;; ----------------------------------------
;; Maybe: (Maybe T) = T or #false
;; ----------------------------------------

;; (Maybe Number): accepts numbers and #false, rejects other types
(check-equal? (say-no (apply-signature (Maybe Number) 42)) 42)
(check-equal? (say-no (apply-signature (Maybe Number) -3.5)) -3.5)
(check-equal? (say-no (apply-signature (Maybe Number) #f)) #f)
(check-equal? (say-no (apply-signature (Maybe Number) "x")) 'no)
(check-equal? (say-no (apply-signature (Maybe Number) #t)) 'no)
(check-equal? (say-no (apply-signature (Maybe Number) '())) 'no)

;; (Maybe String): accepts strings and #false
(check-equal? (say-no (apply-signature (Maybe String) "hello")) "hello")
(check-equal? (say-no (apply-signature (Maybe String) #f)) #f)
(check-equal? (say-no (apply-signature (Maybe String) 42)) 'no)

;; (Maybe Boolean): #t and #f are both booleans, and #f is also #false —
;; so both are accepted.
(check-equal? (say-no (apply-signature (Maybe Boolean) #t)) #t)
(check-equal? (say-no (apply-signature (Maybe Boolean) #f)) #f)
(check-equal? (say-no (apply-signature (Maybe Boolean) 0)) 'no)

;; (Maybe Natural): 0 and positive integers accepted; negatives rejected
(check-equal? (say-no (apply-signature (Maybe Natural) 0)) 0)
(check-equal? (say-no (apply-signature (Maybe Natural) 5)) 5)
(check-equal? (say-no (apply-signature (Maybe Natural) #f)) #f)
(check-equal? (say-no (apply-signature (Maybe Natural) -1)) 'no)

;; Name is preserved regardless of argument
(check-equal? (signature-name (Maybe Number)) 'Maybe)
(check-equal? (signature-name (Maybe String)) 'Maybe)
