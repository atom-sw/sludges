#lang htdp/bsl

;; Tests for the shadowed define-struct in BSL.
;;
;; Our define-struct shadows the native one and dispatches:
;;   (define-struct name (f1 f2))           → untyped (delegates to native)
;;   (define-struct name [(f1 Sig1) ...])   → typed (same as define-struct/typed)
;;
;; In BSL, both variants should produce first-order struct functions.

(require sludges)

;; ========================================
;; Untyped define-struct (delegates to native beginner-define-struct)
;; ========================================

(define-struct point (x y))

(define pt (make-point 3 4))

(check-expect (point? pt) #true)
(check-expect (point-x pt) 3)
(check-expect (point-y pt) 4)
(check-expect (point? 42) #false)

;; Untyped structs still get signatures from native define-struct
(: origin Point)
(define origin (make-point 0 0))
(check-expect (point-x origin) 0)

;; ========================================
;; Typed define-struct (dispatches to define-struct/typed)
;; ========================================

(define-struct pet [(name String) (age Natural)])

(define p1 (make-pet "Rex" 5))

(check-expect (pet? p1) #true)
(check-expect (pet-name p1) "Rex")
(check-expect (pet-age p1) 5)

;; : declaration with generated Pet signature
(: p2 Pet)
(define p2 (make-pet "Luna" 3))
(check-expect (pet-name p2) "Luna")

;; ========================================
;; Both forms coexist in the same module
;; ========================================

;; Another untyped struct
(define-struct color (r g b))

(define red (make-color 255 0 0))
(check-expect (color-r red) 255)
(check-expect (color-g red) 0)
(check-expect (color-b red) 0)

;; Another typed struct
(define-struct record [(label String) (value Integer)])

(: r1 Record)
(define r1 (make-record "x" 42))
(check-expect (record-label r1) "x")
(check-expect (record-value r1) 42)

;; ========================================
;; Typed with hyphenated name
;; ========================================

(define-struct int-pair [(fst Integer) (snd Integer)])

(: ip IntPair)
(define ip (make-int-pair 10 20))
(check-expect (int-pair-fst ip) 10)
(check-expect (int-pair-snd ip) 20)

;; ========================================
;; Parametric NameOf from typed define-struct
;; ========================================

(: p3 (PetOf String Natural))
(define p3 (make-pet "Max" 2))
(check-expect (pet-name p3) "Max")
