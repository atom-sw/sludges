#lang htdp/asl

;; Tests for define-struct in ASL.
;;
;; In ASL, define-struct generates setters (set-X-field!) in addition to
;; constructor, predicate, and accessors.  Both the untyped and typed
;; forms should produce setters.
;;
;; NOTE: check-expect tests run at the end of the module in student
;; languages.  With mutation, we must test post-mutation state or use
;; separate instances for pre/post checks.

(require sludges)

;; ========================================
;; Untyped define-struct — delegates to advanced-define-struct
;; ========================================

(define-struct point (x y))

;; Basic constructor/predicate/accessors
(define pt1 (make-point 3 4))
(check-expect (point? pt1) #true)
(check-expect (point-x pt1) 3)
(check-expect (point-y pt1) 4)
(check-expect (point? 42) #false)

;; Setters: use a separate instance to avoid interfering with above
(define pt2 (make-point 0 0))
(set-point-x! pt2 10)
(set-point-y! pt2 20)
(check-expect (point-x pt2) 10)
(check-expect (point-y pt2) 20)

;; ========================================
;; Typed define-struct — uses advanced-define-struct internally
;; ========================================

(define-struct pet [(name String) (age Natural)])

;; Basic usage (no mutation on this instance)
(define p1 (make-pet "Rex" 5))
(check-expect (pet? p1) #true)
(check-expect (pet-name p1) "Rex")
(check-expect (pet-age p1) 5)

;; Setters on a separate instance
(define p-mut (make-pet "Temp" 0))
(set-pet-name! p-mut "Buddy")
(set-pet-age! p-mut 7)
(check-expect (pet-name p-mut) "Buddy")
(check-expect (pet-age p-mut) 7)

;; : declaration with generated Pet signature
(: p2 Pet)
(define p2 (make-pet "Luna" 3))
(check-expect (pet-name p2) "Luna")

;; ========================================
;; Typed with hyphenated name — setters too
;; ========================================

(define-struct int-pair [(fst Integer) (snd Integer)])

(define ip1 (make-int-pair 10 20))
(check-expect (int-pair-fst ip1) 10)
(check-expect (int-pair-snd ip1) 20)

(define ip-mut (make-int-pair 0 0))
(set-int-pair-fst! ip-mut 100)
(set-int-pair-snd! ip-mut 200)
(check-expect (int-pair-fst ip-mut) 100)
(check-expect (int-pair-snd ip-mut) 200)

(: ip2 IntPair)
(define ip2 (make-int-pair -3 7))
(check-expect (int-pair-fst ip2) -3)

;; ========================================
;; Typed define-struct/typed also gets setters in ASL
;; ========================================

(define-struct/typed record [(label String) (value Integer)])

(define r1 (make-record "x" 42))
(check-expect (record-label r1) "x")
(check-expect (record-value r1) 42)

(define r-mut (make-record "temp" 0))
(set-record-value! r-mut 99)
(check-expect (record-value r-mut) 99)

(: r2 Record)
(define r2 (make-record "y" -10))
(check-expect (record-label r2) "y")

;; ========================================
;; Parametric NameOf works
;; ========================================

(: p3 (PetOf String Natural))
(define p3 (make-pet "Max" 2))
(check-expect (pet-name p3) "Max")

;; ========================================
;; Struct functions are higher-order in ASL
;; ========================================

(check-expect (map pet-name (list (make-pet "A" 1) (make-pet "B" 2)))
              (list "A" "B"))
