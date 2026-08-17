#lang racket/base

;; Tests for interval forms inside define-type
;; (expand-interval-forms compile-time rewriting)

(require rackunit
         (only-in lang/private/teach
                  signature
                  Integer Natural Number String)
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

;; ============================================================
;; 1. Simple define-type with each interval form
;; ============================================================

;; --- integer-from-to [lo, hi] ---

(define-type IFT (integer-from-to 0 10))

(check-equal? (say-no (apply-signature IFT 0)) 0)
(check-equal? (say-no (apply-signature IFT 5)) 5)
(check-equal? (say-no (apply-signature IFT 10)) 10)
(check-equal? (say-no (apply-signature IFT -1)) 'no)
(check-equal? (say-no (apply-signature IFT 11)) 'no)
(check-equal? (say-no (apply-signature IFT 3.5)) 'no)
(check-equal? (say-no (apply-signature IFT "x")) 'no)

;; --- integer-from [lo, +inf) ---

(define-type IF (integer-from 5))

(check-equal? (say-no (apply-signature IF 5)) 5)
(check-equal? (say-no (apply-signature IF 100)) 100)
(check-equal? (say-no (apply-signature IF 4)) 'no)
(check-equal? (say-no (apply-signature IF 5.5)) 'no)

;; --- integer-to (-inf, hi] ---

(define-type IT (integer-to 10))

(check-equal? (say-no (apply-signature IT 10)) 10)
(check-equal? (say-no (apply-signature IT -100)) -100)
(check-equal? (say-no (apply-signature IT 11)) 'no)
(check-equal? (say-no (apply-signature IT 9.5)) 'no)

;; --- number-from-to [lo, hi] ---

(define-type NFT (number-from-to 0.0 1.0))

(check-equal? (say-no (apply-signature NFT 0.0)) 0.0)
(check-equal? (say-no (apply-signature NFT 0.5)) 0.5)
(check-equal? (say-no (apply-signature NFT 1.0)) 1.0)
(check-equal? (say-no (apply-signature NFT -0.1)) 'no)
(check-equal? (say-no (apply-signature NFT 1.1)) 'no)
(check-equal? (say-no (apply-signature NFT "x")) 'no)

;; --- number-from<-to (lo, hi] ---

(define-type NFLT (number-from<-to 0.0 1.0))

(check-equal? (say-no (apply-signature NFLT 0.0)) 'no)   ; open lower
(check-equal? (say-no (apply-signature NFLT 0.5)) 0.5)
(check-equal? (say-no (apply-signature NFLT 1.0)) 1.0)    ; closed upper
(check-equal? (say-no (apply-signature NFLT -0.1)) 'no)
(check-equal? (say-no (apply-signature NFLT 1.1)) 'no)

;; --- number-from-<to [lo, hi) ---

(define-type NFLT2 (number-from-<to 0.0 1.0))

(check-equal? (say-no (apply-signature NFLT2 0.0)) 0.0)   ; closed lower
(check-equal? (say-no (apply-signature NFLT2 0.5)) 0.5)
(check-equal? (say-no (apply-signature NFLT2 1.0)) 'no)   ; open upper
(check-equal? (say-no (apply-signature NFLT2 -0.1)) 'no)
(check-equal? (say-no (apply-signature NFLT2 1.1)) 'no)

;; --- number-from<-<to (lo, hi) ---

(define-type NFLLT (number-from<-<to 0.0 1.0))

(check-equal? (say-no (apply-signature NFLLT 0.0)) 'no)   ; open lower
(check-equal? (say-no (apply-signature NFLLT 0.5)) 0.5)
(check-equal? (say-no (apply-signature NFLLT 1.0)) 'no)   ; open upper
(check-equal? (say-no (apply-signature NFLLT 0.001)) 0.001)
(check-equal? (say-no (apply-signature NFLLT 0.999)) 0.999)
(check-equal? (say-no (apply-signature NFLLT -1)) 'no)

;; --- number-from [lo, +inf) ---

(define-type NF (number-from 3.14))

(check-equal? (say-no (apply-signature NF 3.14)) 3.14)
(check-equal? (say-no (apply-signature NF 100)) 100)
(check-equal? (say-no (apply-signature NF 3.13)) 'no)
(check-equal? (say-no (apply-signature NF "x")) 'no)

;; --- number-from< (lo, +inf) ---

(define-type NFL (number-from< 0))

(check-equal? (say-no (apply-signature NFL 0)) 'no)       ; open lower
(check-equal? (say-no (apply-signature NFL 0.001)) 0.001)
(check-equal? (say-no (apply-signature NFL 100)) 100)
(check-equal? (say-no (apply-signature NFL -1)) 'no)

;; --- number-to (-inf, hi] ---

(define-type NT (number-to 100))

(check-equal? (say-no (apply-signature NT 100)) 100)      ; closed upper
(check-equal? (say-no (apply-signature NT -1000)) -1000)
(check-equal? (say-no (apply-signature NT 100.1)) 'no)
(check-equal? (say-no (apply-signature NT "x")) 'no)

;; --- number-<to (-inf, hi) ---

(define-type NLT (number-<to 0))

(check-equal? (say-no (apply-signature NLT 0)) 'no)       ; open upper
(check-equal? (say-no (apply-signature NLT -0.001)) -0.001)
(check-equal? (say-no (apply-signature NLT -1000)) -1000)
(check-equal? (say-no (apply-signature NLT 1)) 'no)

;; ============================================================
;; 2. Signature names carry the define-type name
;; ============================================================

(check-equal? (signature-name IFT) 'IFT)
(check-equal? (signature-name IF) 'IF)
(check-equal? (signature-name IT) 'IT)
(check-equal? (signature-name NFT) 'NFT)
(check-equal? (signature-name NFLT) 'NFLT)
(check-equal? (signature-name NFLT2) 'NFLT2)
(check-equal? (signature-name NFLLT) 'NFLLT)
(check-equal? (signature-name NF) 'NF)
(check-equal? (signature-name NFL) 'NFL)
(check-equal? (signature-name NT) 'NT)
(check-equal? (signature-name NLT) 'NLT)

;; ============================================================
;; 3. Nested inside one-of / mixed
;; ============================================================

(define-type IntOrRange (one-of (integer-from-to 0 5) String))

(check-equal? (say-no (apply-signature IntOrRange 3)) 3)
(check-equal? (say-no (apply-signature IntOrRange "hello")) "hello")
(check-equal? (say-no (apply-signature IntOrRange 10)) 'no)
(check-equal? (say-no (apply-signature IntOrRange #t)) 'no)
(check-equal? (signature-name IntOrRange) 'IntOrRange)

;; Multiple intervals in one-of
(define-type PosOrNeg
  (one-of (number-from< 0) (number-<to 0)))

(check-equal? (say-no (apply-signature PosOrNeg 5)) 5)
(check-equal? (say-no (apply-signature PosOrNeg -5)) -5)
(check-equal? (say-no (apply-signature PosOrNeg 0)) 'no)  ; neither (0,+inf) nor (-inf,0)
(check-equal? (signature-name PosOrNeg) 'PosOrNeg)

;; Interval nested inside mixed (alias)
(define-type ScoreOrNA (mixed (integer-from-to 0 100) String))

(check-equal? (say-no (apply-signature ScoreOrNA 50)) 50)
(check-equal? (say-no (apply-signature ScoreOrNA "N/A")) "N/A")
(check-equal? (say-no (apply-signature ScoreOrNA 101)) 'no)

;; Interval + ListOf in one-of
(define-type SingleOrList
  (one-of (number-from-to 0 1) (ListOf Number)))

(check-equal? (say-no (apply-signature SingleOrList 0.5)) 0.5)
(check-equal? (say-no (apply-signature SingleOrList (list 1 2 3))) (list 1 2 3))
(check-equal? (say-no (apply-signature SingleOrList 2)) 'no)

;; ============================================================
;; 4. Parametric define-type with intervals
;; ============================================================

;; Two-parameter integer range
(define-type (IntRange lo hi) (integer-from-to lo hi))

(check-equal? (say-no (apply-signature (IntRange 1 5) 3)) 3)
(check-equal? (say-no (apply-signature (IntRange 1 5) 1)) 1)
(check-equal? (say-no (apply-signature (IntRange 1 5) 5)) 5)
(check-equal? (say-no (apply-signature (IntRange 1 5) 0)) 'no)
(check-equal? (say-no (apply-signature (IntRange 1 5) 6)) 'no)
(check-equal? (signature-name (IntRange 1 5)) 'IntRange)

;; Single-parameter: from lo
(define-type (AtLeast lo) (number-from lo))

(check-equal? (say-no (apply-signature (AtLeast 0) 0)) 0)
(check-equal? (say-no (apply-signature (AtLeast 0) 42.5)) 42.5)
(check-equal? (say-no (apply-signature (AtLeast 0) -1)) 'no)
(check-equal? (signature-name (AtLeast 0)) 'AtLeast)

;; Parametric with open endpoints
(define-type (StrictBetween lo hi) (number-from<-<to lo hi))

(check-equal? (say-no (apply-signature (StrictBetween 0 10) 5)) 5)
(check-equal? (say-no (apply-signature (StrictBetween 0 10) 0)) 'no)   ; open lo
(check-equal? (say-no (apply-signature (StrictBetween 0 10) 10)) 'no)  ; open hi
(check-equal? (say-no (apply-signature (StrictBetween 0 10) 0.001)) 0.001)

;; ============================================================
;; 5. Validation errors inside define-type (parametric)
;; ============================================================

;; For parametric define-type, validation is embedded in the predicate
;; body (inside a delay). Errors fire when the signature is first
;; applied (i.e., when the delay promise is forced), not at
;; constructor call time.

;; Bad argument types — error on first apply-signature
(check-exn exn:fail?
  (lambda () (apply-signature (IntRange 1.5 5) 2)))    ; non-integer lo
(check-exn exn:fail?
  (lambda () (apply-signature (IntRange 1 "x") 2)))    ; non-integer hi

;; Range violation — error on first apply-signature
(check-exn exn:fail?
  (lambda () (apply-signature (IntRange 5 1) 3)))      ; lo > hi

;; ============================================================
;; 6. Integer bounds with integer literals (common use case)
;; ============================================================

(define-type Digit (integer-from-to 0 9))

(check-equal? (say-no (apply-signature Digit 0)) 0)
(check-equal? (say-no (apply-signature Digit 9)) 9)
(check-equal? (say-no (apply-signature Digit 5)) 5)
(check-equal? (say-no (apply-signature Digit -1)) 'no)
(check-equal? (say-no (apply-signature Digit 10)) 'no)
(check-equal? (say-no (apply-signature Digit 4.5)) 'no)

;; ============================================================
;; 7. Negative bounds
;; ============================================================

(define-type NegRange (integer-from-to -10 -1))

(check-equal? (say-no (apply-signature NegRange -10)) -10)
(check-equal? (say-no (apply-signature NegRange -5)) -5)
(check-equal? (say-no (apply-signature NegRange -1)) -1)
(check-equal? (say-no (apply-signature NegRange 0)) 'no)
(check-equal? (say-no (apply-signature NegRange -11)) 'no)

;; ============================================================
;; 8. Singleton integer range
;; ============================================================

(define-type JustZero (integer-from-to 0 0))

(check-equal? (say-no (apply-signature JustZero 0)) 0)
(check-equal? (say-no (apply-signature JustZero 1)) 'no)
(check-equal? (say-no (apply-signature JustZero -1)) 'no)
