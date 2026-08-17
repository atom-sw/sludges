#lang racket/base

(require rackunit
         (only-in lang/private/teach
                  signature
                  Integer String False
                  Number EmptyList ConsOf)
         deinprogramm/signature/signature
         sludges)

;; ----------------------------------------
;; Helper: capture the violation message
;; ----------------------------------------
;; Trigger a violation and return the message argument received by
;; signature-violation-proc.  Works in the test context where our
;; wrapper delegates to the default proc (which raises an exception
;; whose message is the string we produced).

(define-syntax capture-violation-message
  (syntax-rules ()
    [(_ body ...)
     (with-handlers ([exn:fail:contract:signature?
                      (lambda (e) (exn-message e))])
       body ...
       ;; if no violation, return #f
       #f)]))

;; ----------------------------------------
;; Named signatures produce enhanced messages
;; ----------------------------------------

(define-type PossiblyString (one-of String False))

;; Violation on a define-type signature: includes the type name
(check-equal?
 (capture-violation-message (apply-signature PossiblyString 3))
 "expected a PossiblyString, but got 3")

;; No violation when value satisfies the signature
(check-equal?
 (capture-violation-message (apply-signature PossiblyString "hello"))
 #f)

(check-equal?
 (capture-violation-message (apply-signature PossiblyString #f))
 #f)

;; ----------------------------------------
;; Built-in named signatures also get enhanced messages
;; ----------------------------------------

(check-equal?
 (capture-violation-message (apply-signature Integer "oops"))
 "expected an Integer, but got \"oops\"")

(check-equal?
 (capture-violation-message (apply-signature String 42))
 "expected a String, but got 42")

;; ----------------------------------------
;; Anonymous signatures fall back to default format
;; ----------------------------------------
;; A bare (signature (predicate ...)) without a name wrapping it
;; has signature-name = #f, so our wrapper passes message = #f
;; to the default proc, which produces "got <value>".

(define anon-sig (signature (predicate even?)))

(check-equal? (signature-name anon-sig) #f)
(check-equal?
 (capture-violation-message (apply-signature anon-sig 3))
 "got 3")  ;; anonymous sigs still use default format

;; ----------------------------------------
;; sludges interval signatures have names
;; ----------------------------------------

(define MyRange (integer-from-to 1 10))

(check-equal?
 (capture-violation-message (apply-signature MyRange 0))
 "expected an integer-from-to, but got 0")

(check-equal?
 (capture-violation-message (apply-signature MyRange 5))
 #f)

;; ----------------------------------------
;; Recursive types: violation message includes the type name
;; and reports the top-level value, not the inner failing sub-value.
;; ----------------------------------------

(define-type Min2List (one-of
                       (ConsOf Number (ConsOf Number EmptyList))
                       (ConsOf Number Min2List)))

;; NL1 case: '() is not a pair at all → immediate top-level failure
(check-equal?
 (capture-violation-message (apply-signature Min2List '()))
 "expected a Min2List, but got '()")

;; NL2 case: (list 3) = (cons 3 '()).  Outer pair passes, but the
;; cdr '() fails all inner alternatives.  The violation should report
;; the top-level value (list 3) and the type Min2List — NOT just
;; the inner failing sub-value '().
(check-equal?
 (capture-violation-message (apply-signature Min2List (list 3)))
 "expected a Min2List, but got '(3)")

;; Valid values pass without violation
(check-equal?
 (capture-violation-message (apply-signature Min2List (list 1 2)))
 #f)

(check-equal?
 (capture-violation-message (apply-signature Min2List (list 1 2 3 4)))
 #f)

;; Wrong element type: "hello" is not a Number — but the top-level
;; value is reported (the mixed catches the inner violation).
(check-equal?
 (capture-violation-message (apply-signature Min2List (list "hello" 2)))
 "expected a Min2List, but got '(\"hello\" 2)")

;; Deeper failure: (list 1 2 3) has 3 elements; the cdr (list 2 3)
;; satisfies the 2-element base case, so (list 1 2 3) is valid.
(check-equal?
 (capture-violation-message (apply-signature Min2List (list 1 2 3)))
 #f)
