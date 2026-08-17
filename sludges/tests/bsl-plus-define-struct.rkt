#lang htdp/bsl+

;; Tests for define-struct/typed in BSL+.
;;
;; BSL+ is like BSL (first-order struct functions) but adds lambda.
;; define-struct/typed should add first-order wrappers just like in BSL.

(require sludges)

;; ========================================
;; Basic typed struct
;; ========================================

(define-struct/typed pet [(name String) (age Natural)])

(define p1 (make-pet "Rex" 5))

(check-expect (pet? p1) #true)
(check-expect (pet-name p1) "Rex")
(check-expect (pet-age p1) 5)

(: p2 Pet)
(define p2 (make-pet "Luna" 3))

(check-expect (pet-name p2) "Luna")
(check-expect (pet-age p2) 3)

;; predicate returns false for non-pet values
(check-expect (pet? 42) #false)
(check-expect (pet? "hello") #false)

;; ========================================
;; Typed struct with different field types
;; ========================================

(define-struct/typed record [(label String) (value Integer)])

(define r1 (make-record "x" 42))
(check-expect (record? r1) #true)
(check-expect (record-label r1) "x")
(check-expect (record-value r1) 42)

(: r2 Record)
(define r2 (make-record "y" -10))
(check-expect (record-label r2) "y")

;; ========================================
;; Hyphenated struct name
;; ========================================

(define-struct/typed int-pair [(fst Integer) (snd Integer)])

(define ip1 (make-int-pair 10 20))
(check-expect (int-pair? ip1) #true)
(check-expect (int-pair-fst ip1) 10)
(check-expect (int-pair-snd ip1) 20)

(: ip2 IntPair)
(define ip2 (make-int-pair -3 7))
(check-expect (int-pair-fst ip2) -3)

;; ========================================
;; Struct with Boolean field
;; ========================================

(define-struct/typed flag [(label String) (active Boolean)])

(: f1 Flag)
(define f1 (make-flag "test" #true))
(check-expect (flag-label f1) "test")
(check-expect (flag-active f1) #true)

;; ========================================
;; NameOf parametric signature works
;; ========================================

(: p3 (PetOf String Natural))
(define p3 (make-pet "Max" 2))
(check-expect (pet-name p3) "Max")

(: ip3 (IntPairOf Integer Integer))
(define ip3 (make-int-pair 100 200))
(check-expect (int-pair-fst ip3) 100)

;; ========================================
;; BSL+ specific: lambda works alongside define-struct/typed
;; ========================================

;; BSL+ adds lambda for function definitions.
;; define-type with a student-defined predicate using lambda syntax.
(define even-nat?
  (lambda (x) (and (integer? x) (>= x 0) (even? x))))

(define-type EvenNat (predicate even-nat?))

(: en1 EvenNat)
(define en1 42)
(check-expect en1 42)

;; ========================================
;; First-order wrappers are in place
;; ========================================
;;
;; Verified implicitly: if wrappers were absent, BSL+'s #%module-begin
;; would reject struct function usage.  The fact that all calls above
;; compile and run demonstrates the wrappers work correctly.
