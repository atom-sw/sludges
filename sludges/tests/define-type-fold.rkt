#lang racket/base

;; Tests for ConsOf prefix folding in define-type.
;;
;; When a mixed/one-of body contains multiple ConsOf branches that share
;; the same car signature, define-type automatically folds them into a
;; single ConsOf with an inner mixed in the cdr position:
;;
;;   (mixed (ConsOf A B) (ConsOf A C))
;;   => (ConsOf A (mixed B C))
;;
;; This is semantically equivalent but avoids a bug in DeinProgramm's
;; fold-lazy-wrap-signatures that incorrectly rejects values when a mixed
;; form contains ConsOf branches at different nesting depths.

(require rackunit
         (only-in lang/private/teach
                  signature
                  ConsOf EmptyList
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
;; Basic case: the original DeinProgramm bug reproduction
;;
;; Without folding, (list 1 2) is falsely rejected by the buggy
;; fold-lazy-wrap-signatures when two ConsOf branches have different depths.
;; With folding, the body becomes (ConsOf Number (mixed (ConsOf Number EmptyList) List2+))
;; which avoids the bug entirely.
;; ----------------------------------------

(define-type List2+
  (one-of (ConsOf Number (ConsOf Number EmptyList))
          (ConsOf Number List2+)))

;; Must accept lists with 2 or more numbers
(check-equal? (say-no (apply-signature List2+ (list 1 2))) (list 1 2))
(check-equal? (say-no (apply-signature List2+ (list 1 2 3))) (list 1 2 3))
(check-equal? (say-no (apply-signature List2+ (list 1 2 3 4 5))) (list 1 2 3 4 5))

;; Must reject lists with fewer than 2 elements
(check-equal? (say-no (apply-signature List2+ '())) 'no)
(check-equal? (say-no (apply-signature List2+ (list 1))) 'no)

;; Must reject non-lists
(check-equal? (say-no (apply-signature List2+ 42)) 'no)
(check-equal? (say-no (apply-signature List2+ "hello")) 'no)

;; ----------------------------------------
;; Exact-length list signatures
;;
;; (ConsOf A (ConsOf B EmptyList)) is a list of exactly [A, B].
;; Three alternatives with shared prefix — all should fold into one ConsOf.
;; ----------------------------------------

(define-type ExactList1Or2Or3
  (one-of (ConsOf Number EmptyList)
          (ConsOf Number (ConsOf Number EmptyList))
          (ConsOf Number (ConsOf Number (ConsOf Number EmptyList)))))

(check-equal? (say-no (apply-signature ExactList1Or2Or3 (list 1))) (list 1))
(check-equal? (say-no (apply-signature ExactList1Or2Or3 (list 1 2))) (list 1 2))
(check-equal? (say-no (apply-signature ExactList1Or2Or3 (list 1 2 3))) (list 1 2 3))
(check-equal? (say-no (apply-signature ExactList1Or2Or3 '())) 'no)
(check-equal? (say-no (apply-signature ExactList1Or2Or3 (list 1 2 3 4))) 'no)
(check-equal? (say-no (apply-signature ExactList1Or2Or3 (list "a"))) 'no)

;; ----------------------------------------
;; Mixed ConsOf and non-ConsOf alternatives
;;
;; Non-ConsOf alternatives should pass through unchanged.
;; ConsOf alternatives with the same car should be folded.
;; ----------------------------------------

(define-type NumberListOrBool
  (one-of Boolean
          (ConsOf Number EmptyList)
          (ConsOf Number (ConsOf Number EmptyList))))

(check-equal? (say-no (apply-signature NumberListOrBool #t)) #t)
(check-equal? (say-no (apply-signature NumberListOrBool #f)) #f)
(check-equal? (say-no (apply-signature NumberListOrBool (list 1))) (list 1))
(check-equal? (say-no (apply-signature NumberListOrBool (list 1 2))) (list 1 2))
(check-equal? (say-no (apply-signature NumberListOrBool '())) 'no)
(check-equal? (say-no (apply-signature NumberListOrBool 42)) 'no)

;; ----------------------------------------
;; ConsOf branches with different car signatures — no folding expected
;; (they should still work correctly)
;; ----------------------------------------

(define-type NumberOrStringList
  (one-of (ConsOf Number EmptyList)
          (ConsOf String EmptyList)))

(check-equal? (say-no (apply-signature NumberOrStringList (list 1))) (list 1))
(check-equal? (say-no (apply-signature NumberOrStringList (list "x"))) (list "x"))
(check-equal? (say-no (apply-signature NumberOrStringList (list #t))) 'no)
(check-equal? (say-no (apply-signature NumberOrStringList '())) 'no)

;; ----------------------------------------
;; The mixed keyword (vs one-of) also triggers folding
;; ----------------------------------------

(define-type List2+/mixed
  (mixed (ConsOf Number (ConsOf Number EmptyList))
         (ConsOf Number List2+/mixed)))

(check-equal? (say-no (apply-signature List2+/mixed (list 1 2))) (list 1 2))
(check-equal? (say-no (apply-signature List2+/mixed (list 1 2 3))) (list 1 2 3))
(check-equal? (say-no (apply-signature List2+/mixed '())) 'no)
(check-equal? (say-no (apply-signature List2+/mixed (list 1))) 'no)

;; ----------------------------------------
;; Single ConsOf branch — no folding, should still work
;; ----------------------------------------

(define-type NonEmptyNumberList
  (one-of (ConsOf Number EmptyList)
          (ConsOf Number NonEmptyNumberList)))

(check-equal? (say-no (apply-signature NonEmptyNumberList (list 1))) (list 1))
(check-equal? (say-no (apply-signature NonEmptyNumberList (list 1 2 3))) (list 1 2 3))
(check-equal? (say-no (apply-signature NonEmptyNumberList '())) 'no)
(check-equal? (say-no (apply-signature NonEmptyNumberList 42)) 'no)

;; ----------------------------------------
;; No mixed at all — body unchanged, normal define-type behavior
;; ----------------------------------------

(define-type JustNumber Number)

(check-equal? (say-no (apply-signature JustNumber 42)) 42)
(check-equal? (say-no (apply-signature JustNumber "x")) 'no)

;; ----------------------------------------
;; Name is preserved by define-type even after folding
;; ----------------------------------------

(check-equal? (signature-name List2+) 'List2+)
(check-equal? (signature-name ExactList1Or2Or3) 'ExactList1Or2Or3)
(check-equal? (signature-name NumberListOrBool) 'NumberListOrBool)

;; ----------------------------------------
;; Cross-type interaction: Bug 2 (andmap crash in signature=?)
;;
;; When two recursive ConsOf-based types with different nesting depths
;; are both applied to the same cons cells, DeinProgramm's signature=?
;; for mixed uses andmap on lists of different lengths (crashing).
;; The combined wrapper on inner mixed forms prevents this by making
;; the inner mixed opaque to flatten-mixed-signatures and
;; fold-lazy-wrap-signatures.
;; ----------------------------------------

;; Type 1: non-empty list (1+ elements)
(define-type NEL
  (one-of (ConsOf Number EmptyList)
          (ConsOf Number NEL)))

;; Type 2: at-least-two list (2+ elements) — different nesting depth
(define-type List2+/cross
  (one-of (ConsOf Number (ConsOf Number EmptyList))
          (ConsOf Number List2+/cross)))

;; Basic acceptance for each type
(check-equal? (say-no (apply-signature NEL (list 1))) (list 1))
(check-equal? (say-no (apply-signature NEL (list 1 2))) (list 1 2))
(check-equal? (say-no (apply-signature NEL (list 1 2 3))) (list 1 2 3))
(check-equal? (say-no (apply-signature List2+/cross (list 1 2))) (list 1 2))
(check-equal? (say-no (apply-signature List2+/cross (list 1 2 3))) (list 1 2 3))

;; Cross-type: sign with List2+/cross first, then with NEL (same cons cells)
;; This is the scenario that triggers Bug 2 without the combined wrapper.
(let ([v (list 5 12 -2)])
  (define signed-mtl (say-no (apply-signature List2+/cross v)))
  (check-not-equal? signed-mtl 'no "List2+/cross should accept (5 12 -2)")
  ;; Now apply NEL to the same (already-signed) value
  (define signed-nel (say-no (apply-signature NEL signed-mtl)))
  (check-not-equal? signed-nel 'no "NEL should accept value already signed with List2+/cross"))

;; Cross-type: sign with NEL first, then with List2+/cross
(let ([v (list 3 7 11)])
  (define signed-nel (say-no (apply-signature NEL v)))
  (check-not-equal? signed-nel 'no "NEL should accept (3 7 11)")
  (define signed-mtl (say-no (apply-signature List2+/cross signed-nel)))
  (check-not-equal? signed-mtl 'no "List2+/cross should accept value already signed with NEL"))

;; Cross-type: sublists also get signed; verify they survive re-signing
(let ([v (list 1 2 3 4)])
  (define signed (say-no (apply-signature List2+/cross v)))
  (check-not-equal? signed 'no)
  ;; The cdr is (2 3 4), which should be valid for both types
  (define sub (cdr signed))
  (check-not-equal? (say-no (apply-signature NEL sub)) 'no
                    "sublist (2 3 4) should be valid as NEL")
  (check-not-equal? (say-no (apply-signature List2+/cross sub)) 'no
                    "sublist (2 3 4) should be valid as List2+/cross"))

;; ----------------------------------------
;; Cons, the alias of ConsOf, folds the same way
;; ----------------------------------------
;; The fold keys on the head of each branch, so it has to recognize either
;; spelling.  Without that, a type written with Cons would skip the fold and
;; hit the very DeinProgramm bug the fold exists to avoid.

(define-type Two+ConsOf (one-of (ConsOf String (ConsOf String EmptyList))
                                (ConsOf String Two+ConsOf)))
(define-type Two+Cons   (one-of (Cons String (Cons String EmptyList))
                                (Cons String Two+Cons)))
;; the two spellings may even be mixed within one definition
(define-type Two+Both   (one-of (Cons String (ConsOf String EmptyList))
                                (ConsOf String Two+Both)))

(define (accepts? t v) (not (eq? (say-no (apply-signature t v)) 'no)))

(for ([t (list Two+ConsOf Two+Cons Two+Both)]
      [name '(Two+ConsOf Two+Cons Two+Both)])
  (check-true  (accepts? t '("a" "b"))     (format "~a accepts two strings" name))
  (check-true  (accepts? t '("a" "b" "c")) (format "~a accepts three strings" name))
  (check-false (accepts? t (list "a" 1))   (format "~a rejects a non-string" name))
  (check-false (accepts? t 5)              (format "~a rejects a non-list" name)))

;; Cons is the same function as ConsOf, not a copy
(check-eq? Cons ConsOf)
