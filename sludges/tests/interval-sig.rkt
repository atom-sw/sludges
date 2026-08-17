#lang racket/base

(require rackunit
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
;; integer-from-to: [lo, hi]
;; ----------------------------------------

;; Accepts integers in range
(check-equal? (say-no (apply-signature (integer-from-to 1 5) 1)) 1)
(check-equal? (say-no (apply-signature (integer-from-to 1 5) 3)) 3)
(check-equal? (say-no (apply-signature (integer-from-to 1 5) 5)) 5)
(check-equal? (say-no (apply-signature (integer-from-to -3 3) 0)) 0)
(check-equal? (say-no (apply-signature (integer-from-to 0 0) 0)) 0)  ; singleton

;; Rejects integers out of range
(check-equal? (say-no (apply-signature (integer-from-to 1 5) 0)) 'no)
(check-equal? (say-no (apply-signature (integer-from-to 1 5) 6)) 'no)
(check-equal? (say-no (apply-signature (integer-from-to 1 5) -10)) 'no)

;; Rejects non-integers
(check-equal? (say-no (apply-signature (integer-from-to 1 5) 2.5)) 'no)
(check-equal? (say-no (apply-signature (integer-from-to 1 5) "3")) 'no)
(check-equal? (say-no (apply-signature (integer-from-to 1 5) #t)) 'no)

;; Construction errors: bad arg types
(check-exn exn:fail? (lambda () (integer-from-to 1.5 5)))
(check-exn exn:fail? (lambda () (integer-from-to 1 5.5)))
(check-exn exn:fail? (lambda () (integer-from-to "a" 5)))
;; Construction error: lo > hi
(check-exn exn:fail? (lambda () (integer-from-to 5 1)))

;; Name is preserved
(check-equal? (signature-name (integer-from-to 0 10)) 'integer-from-to)

;; ----------------------------------------
;; integer-from: [lo, +∞)
;; ----------------------------------------

(check-equal? (say-no (apply-signature (integer-from 3) 3)) 3)
(check-equal? (say-no (apply-signature (integer-from 3) 100)) 100)
(check-equal? (say-no (apply-signature (integer-from -5) 0)) 0)
(check-equal? (say-no (apply-signature (integer-from 0) 0)) 0)

;; Rejects values below lo
(check-equal? (say-no (apply-signature (integer-from 3) 2)) 'no)
(check-equal? (say-no (apply-signature (integer-from 3) -100)) 'no)

;; Rejects non-integers
(check-equal? (say-no (apply-signature (integer-from 0) 0.5)) 'no)
(check-equal? (say-no (apply-signature (integer-from 0) "0")) 'no)

;; Construction error: non-integer bound
(check-exn exn:fail? (lambda () (integer-from 1.5)))
(check-exn exn:fail? (lambda () (integer-from "a")))

;; Name is preserved
(check-equal? (signature-name (integer-from 0)) 'integer-from)

;; ----------------------------------------
;; integer-to: (-∞, hi]
;; ----------------------------------------

(check-equal? (say-no (apply-signature (integer-to 5) 5)) 5)
(check-equal? (say-no (apply-signature (integer-to 5) -100)) -100)
(check-equal? (say-no (apply-signature (integer-to 0) 0)) 0)

;; Rejects values above hi
(check-equal? (say-no (apply-signature (integer-to 5) 6)) 'no)
(check-equal? (say-no (apply-signature (integer-to 5) 100)) 'no)

;; Rejects non-integers
(check-equal? (say-no (apply-signature (integer-to 5) 4.9)) 'no)
(check-equal? (say-no (apply-signature (integer-to 5) "5")) 'no)

;; Construction error: non-integer bound
(check-exn exn:fail? (lambda () (integer-to 1.5)))
(check-exn exn:fail? (lambda () (integer-to "a")))

;; Name is preserved
(check-equal? (signature-name (integer-to 10)) 'integer-to)

;; ----------------------------------------
;; number-from-to: [lo, hi]  (both closed)
;; ----------------------------------------

;; Accepts values in range (including bounds)
(check-equal? (say-no (apply-signature (number-from-to 1.0 5.0) 1.0)) 1.0)
(check-equal? (say-no (apply-signature (number-from-to 1.0 5.0) 3.14)) 3.14)
(check-equal? (say-no (apply-signature (number-from-to 1.0 5.0) 5.0)) 5.0)
(check-equal? (say-no (apply-signature (number-from-to -1 1) 0)) 0)
(check-equal? (say-no (apply-signature (number-from-to 0 0) 0)) 0)  ; singleton

;; Rejects values out of range
(check-equal? (say-no (apply-signature (number-from-to 1.0 5.0) 0.9)) 'no)
(check-equal? (say-no (apply-signature (number-from-to 1.0 5.0) 5.1)) 'no)

;; Rejects non-numbers
(check-equal? (say-no (apply-signature (number-from-to 0 10) "5")) 'no)
(check-equal? (say-no (apply-signature (number-from-to 0 10) #t)) 'no)

;; Construction errors
(check-exn exn:fail? (lambda () (number-from-to "a" 5)))
(check-exn exn:fail? (lambda () (number-from-to 1 "b")))
(check-exn exn:fail? (lambda () (number-from-to 5.0 1.0)))  ; lo > hi

;; Name is preserved
(check-equal? (signature-name (number-from-to 0 1)) 'number-from-to)

;; ----------------------------------------
;; number-from<-to: (lo, hi]  (lo open, hi closed)
;; ----------------------------------------

;; lo is excluded, hi is included
(check-equal? (say-no (apply-signature (number-from<-to 1.0 5.0) 1.001)) 1.001)
(check-equal? (say-no (apply-signature (number-from<-to 1.0 5.0) 5.0)) 5.0)
(check-equal? (say-no (apply-signature (number-from<-to 1.0 5.0) 3.0)) 3.0)
(check-equal? (say-no (apply-signature (number-from<-to -1 1) 0)) 0)

;; lo itself is rejected
(check-equal? (say-no (apply-signature (number-from<-to 1.0 5.0) 1.0)) 'no)
;; Values below lo are rejected
(check-equal? (say-no (apply-signature (number-from<-to 1.0 5.0) 0.5)) 'no)
;; Values above hi are rejected
(check-equal? (say-no (apply-signature (number-from<-to 1.0 5.0) 5.1)) 'no)

;; Rejects non-numbers
(check-equal? (say-no (apply-signature (number-from<-to 0 1) "0.5")) 'no)

;; Construction error: lo >= hi (open endpoint, so lo=hi is empty → error)
(check-exn exn:fail? (lambda () (number-from<-to 5.0 5.0)))  ; lo = hi
(check-exn exn:fail? (lambda () (number-from<-to 5.0 1.0)))  ; lo > hi
(check-exn exn:fail? (lambda () (number-from<-to "a" 5)))

;; Name is preserved
(check-equal? (signature-name (number-from<-to 0 1)) 'number-from<-to)

;; ----------------------------------------
;; number-from-<to: [lo, hi)  (lo closed, hi open)
;; ----------------------------------------

;; lo is included, hi is excluded
(check-equal? (say-no (apply-signature (number-from-<to 1.0 5.0) 1.0)) 1.0)
(check-equal? (say-no (apply-signature (number-from-<to 1.0 5.0) 4.999)) 4.999)
(check-equal? (say-no (apply-signature (number-from-<to 1.0 5.0) 3.0)) 3.0)

;; hi itself is rejected
(check-equal? (say-no (apply-signature (number-from-<to 1.0 5.0) 5.0)) 'no)
;; Values above hi are rejected
(check-equal? (say-no (apply-signature (number-from-<to 1.0 5.0) 5.1)) 'no)
;; Values below lo are rejected
(check-equal? (say-no (apply-signature (number-from-<to 1.0 5.0) 0.9)) 'no)

;; Rejects non-numbers
(check-equal? (say-no (apply-signature (number-from-<to 0 1) "0.5")) 'no)

;; Construction error: lo >= hi
(check-exn exn:fail? (lambda () (number-from-<to 5.0 5.0)))  ; lo = hi
(check-exn exn:fail? (lambda () (number-from-<to 5.0 1.0)))  ; lo > hi
(check-exn exn:fail? (lambda () (number-from-<to "a" 5)))

;; Name is preserved
(check-equal? (signature-name (number-from-<to 0 1)) 'number-from-<to)

;; ----------------------------------------
;; number-from<-<to: (lo, hi)  (both open)
;; ----------------------------------------

;; Values strictly inside are accepted
(check-equal? (say-no (apply-signature (number-from<-<to 1.0 5.0) 1.001)) 1.001)
(check-equal? (say-no (apply-signature (number-from<-<to 1.0 5.0) 4.999)) 4.999)
(check-equal? (say-no (apply-signature (number-from<-<to 1.0 5.0) 3.0)) 3.0)

;; Both endpoints are rejected
(check-equal? (say-no (apply-signature (number-from<-<to 1.0 5.0) 1.0)) 'no)
(check-equal? (say-no (apply-signature (number-from<-<to 1.0 5.0) 5.0)) 'no)
;; Values outside are rejected
(check-equal? (say-no (apply-signature (number-from<-<to 1.0 5.0) 0.9)) 'no)
(check-equal? (say-no (apply-signature (number-from<-<to 1.0 5.0) 5.1)) 'no)

;; Rejects non-numbers
(check-equal? (say-no (apply-signature (number-from<-<to 0 1) "0.5")) 'no)

;; Construction error: lo >= hi (both open, so lo=hi produces empty interval)
(check-exn exn:fail? (lambda () (number-from<-<to 5.0 5.0)))  ; lo = hi
(check-exn exn:fail? (lambda () (number-from<-<to 5.0 1.0)))  ; lo > hi
(check-exn exn:fail? (lambda () (number-from<-<to "a" 5)))

;; Name is preserved
(check-equal? (signature-name (number-from<-<to 0 1)) 'number-from<-<to)

;; ----------------------------------------
;; number-from: [lo, +∞)  (closed lower bound)
;; ----------------------------------------

(check-equal? (say-no (apply-signature (number-from 2.0) 2.0)) 2.0)
(check-equal? (say-no (apply-signature (number-from 2.0) 100.0)) 100.0)
(check-equal? (say-no (apply-signature (number-from -1.5) 0.0)) 0.0)
(check-equal? (say-no (apply-signature (number-from 0) 0)) 0)

;; lo itself is accepted (closed)
(check-equal? (say-no (apply-signature (number-from 3.14) 3.14)) 3.14)

;; Values below lo are rejected
(check-equal? (say-no (apply-signature (number-from 2.0) 1.999)) 'no)
(check-equal? (say-no (apply-signature (number-from 2.0) -100.0)) 'no)

;; Rejects non-numbers
(check-equal? (say-no (apply-signature (number-from 0) "0")) 'no)
(check-equal? (say-no (apply-signature (number-from 0) #f)) 'no)

;; Construction error: non-real bound
(check-exn exn:fail? (lambda () (number-from "a")))
(check-exn exn:fail? (lambda () (number-from #t)))

;; Name is preserved
(check-equal? (signature-name (number-from 0)) 'number-from)

;; ----------------------------------------
;; number-from<: (lo, +∞)  (open lower bound)
;; ----------------------------------------

(check-equal? (say-no (apply-signature (number-from< 2.0) 2.001)) 2.001)
(check-equal? (say-no (apply-signature (number-from< 2.0) 100.0)) 100.0)
(check-equal? (say-no (apply-signature (number-from< -1.5) 0.0)) 0.0)

;; lo itself is rejected (open)
(check-equal? (say-no (apply-signature (number-from< 2.0) 2.0)) 'no)
;; Values below lo are rejected
(check-equal? (say-no (apply-signature (number-from< 2.0) 1.999)) 'no)
(check-equal? (say-no (apply-signature (number-from< 2.0) -100.0)) 'no)

;; Rejects non-numbers
(check-equal? (say-no (apply-signature (number-from< 0) "1")) 'no)

;; Construction error: non-real bound
(check-exn exn:fail? (lambda () (number-from< "a")))

;; Name is preserved
(check-equal? (signature-name (number-from< 0)) 'number-from<)

;; ----------------------------------------
;; number-to: (-∞, hi]  (closed upper bound)
;; ----------------------------------------

(check-equal? (say-no (apply-signature (number-to 5.0) 5.0)) 5.0)
(check-equal? (say-no (apply-signature (number-to 5.0) -100.0)) -100.0)
(check-equal? (say-no (apply-signature (number-to 0) 0)) 0)

;; hi itself is accepted (closed)
(check-equal? (say-no (apply-signature (number-to 3.14) 3.14)) 3.14)

;; Values above hi are rejected
(check-equal? (say-no (apply-signature (number-to 5.0) 5.001)) 'no)
(check-equal? (say-no (apply-signature (number-to 5.0) 100.0)) 'no)

;; Rejects non-numbers
(check-equal? (say-no (apply-signature (number-to 5) "5")) 'no)
(check-equal? (say-no (apply-signature (number-to 5) #t)) 'no)

;; Construction error: non-real bound
(check-exn exn:fail? (lambda () (number-to "a")))
(check-exn exn:fail? (lambda () (number-to #f)))

;; Name is preserved
(check-equal? (signature-name (number-to 10)) 'number-to)

;; ----------------------------------------
;; number-<to: (-∞, hi)  (open upper bound)
;; ----------------------------------------

(check-equal? (say-no (apply-signature (number-<to 5.0) 4.999)) 4.999)
(check-equal? (say-no (apply-signature (number-<to 5.0) -100.0)) -100.0)
(check-equal? (say-no (apply-signature (number-<to 0) -1)) -1)

;; hi itself is rejected (open)
(check-equal? (say-no (apply-signature (number-<to 5.0) 5.0)) 'no)
;; Values above hi are rejected
(check-equal? (say-no (apply-signature (number-<to 5.0) 5.001)) 'no)
(check-equal? (say-no (apply-signature (number-<to 5.0) 100.0)) 'no)

;; Rejects non-numbers
(check-equal? (say-no (apply-signature (number-<to 5) "4")) 'no)

;; Construction error: non-real bound
(check-exn exn:fail? (lambda () (number-<to "a")))

;; Name is preserved
(check-equal? (signature-name (number-<to 10)) 'number-<to)
