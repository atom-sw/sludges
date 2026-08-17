#lang htdp/isl

;; Tests for the shadowed define-struct in ISL.
;;
;; In ISL, struct functions are higher-order (no first-order wrappers).
;; define-struct supports both untyped and typed forms.

(require sludges)

;; ========================================
;; Untyped define-struct (delegates to native intermediate-define-struct)
;; ========================================

(define-struct point (x y))

(define pt (make-point 3 4))

(check-expect (point? pt) #true)
(check-expect (point-x pt) 3)
(check-expect (point-y pt) 4)
(check-expect (point? 42) #false)

;; ISL allows struct functions as values (higher-order)
(check-expect (map point-x (list (make-point 1 2) (make-point 3 4)))
              (list 1 3))

;; : declaration works with native Point signature
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

(: p2 Pet)
(define p2 (make-pet "Luna" 3))
(check-expect (pet-name p2) "Luna")

;; ISL: struct functions are higher-order in typed structs too
(check-expect (map pet-name (list (make-pet "A" 1) (make-pet "B" 2)))
              (list "A" "B"))

;; ========================================
;; Both forms coexist
;; ========================================

(define-struct color (r g b))
(define-struct record [(label String) (value Integer)])

(define red (make-color 255 0 0))
(check-expect (color-r red) 255)

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

(: ip2 (IntPairOf Integer Integer))
(define ip2 (make-int-pair 100 200))
(check-expect (int-pair-fst ip2) 100)
