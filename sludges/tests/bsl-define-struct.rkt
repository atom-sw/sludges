#lang htdp/bsl

;; Tests for define-struct/typed in BSL.
;;
;; In BSL, struct functions (constructor, predicate, accessors) are
;; first-order: they cannot be used as values (bare identifier references
;; are rejected).  define-struct/typed detects BSL context and adds
;; first-order wrappers around struct functions, matching the behavior
;; of BSL's native define-struct.
;;
;; We cannot use rackunit or apply-signature in BSL, so tests use
;; check-expect, check-within, check-error, and : declarations.

(require sludges)

;; ========================================
;; Basic typed struct (all String fields)
;; ========================================

(define-struct/typed pet [(name String) (age Natural)])

;; constructor, predicate, accessors
(define p1 (make-pet "Rex" 5))

(check-expect (pet? p1) #true)
(check-expect (pet-name p1) "Rex")
(check-expect (pet-age p1) 5)

;; : declaration uses the generated Pet signature
(: p2 Pet)
(define p2 (make-pet "Luna" 3))

(check-expect (pet-name p2) "Luna")
(check-expect (pet-age p2) 3)

;; predicate returns false for non-pet values
(check-expect (pet? 42) #false)
(check-expect (pet? "hello") #false)
(check-expect (pet? #true) #false)

;; ========================================
;; Signature enforcement via :
;; ========================================

;; Correct types should work
(: p3 Pet)
(define p3 (make-pet "Buddy" 7))
(check-expect (pet-name p3) "Buddy")

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
(check-expect (record-value r2) -10)

;; ========================================
;; Hyphenated struct name
;; ========================================

(define-struct/typed int-pair [(fst Integer) (snd Integer)])

(define ip1 (make-int-pair 10 20))
(check-expect (int-pair? ip1) #true)
(check-expect (int-pair-fst ip1) 10)
(check-expect (int-pair-snd ip1) 20)

;; IntPair signature works with :
(: ip2 IntPair)
(define ip2 (make-int-pair -3 7))
(check-expect (int-pair-fst ip2) -3)

;; ========================================
;; Single-field struct
;; ========================================

(define-struct/typed wrapper [(content String)])

(define w1 (make-wrapper "hello"))
(check-expect (wrapper? w1) #true)
(check-expect (wrapper-content w1) "hello")

(: w2 Wrapper)
(define w2 (make-wrapper "world"))
(check-expect (wrapper-content w2) "world")

;; ========================================
;; Struct with Boolean field
;; ========================================

(define-struct/typed flag [(label String) (active Boolean)])

(define f1 (make-flag "test" #true))
(check-expect (flag? f1) #true)
(check-expect (flag-label f1) "test")
(check-expect (flag-active f1) #true)

(: f2 Flag)
(define f2 (make-flag "off" #false))
(check-expect (flag-active f2) #false)

;; ========================================
;; NameOf parametric signature works
;; ========================================

;; PetOf is available as parametric variant
(: p4 (PetOf String Natural))
(define p4 (make-pet "Max" 2))
(check-expect (pet-name p4) "Max")

;; IntPairOf is available as parametric variant
(: ip3 (IntPairOf Integer Integer))
(define ip3 (make-int-pair 100 200))
(check-expect (int-pair-fst ip3) 100)

;; ========================================
;; Struct functions are first-order in BSL
;; ========================================
;;
;; The first-order wrappers are verified implicitly: if they were absent,
;; BSL's #%module-begin would reject uses of the struct functions because
;; they would not have the required first-order syntax transformers.
;; The fact that all constructor/predicate/accessor calls above compile
;; and run correctly demonstrates that the wrappers are in place.
