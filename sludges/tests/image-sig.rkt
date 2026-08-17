#lang racket/base

(require rackunit
         (only-in 2htdp/image circle rectangle text empty-image
                               overlay beside above
                               image-width image-height)
         (only-in lang/posn make-posn)
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
;; Image: non-parametric signature
;; ----------------------------------------

(define img1 (circle 10 "solid" "red"))
(define img2 (rectangle 20 30 "solid" "blue"))
(define img3 (text "hello" 12 "black"))
(define img4 empty-image)

;; accepts image values (check-eq? for same object)
(check-eq? (say-no (apply-signature Image img1)) img1)
(check-eq? (say-no (apply-signature Image img2)) img2)
(check-eq? (say-no (apply-signature Image img3)) img3)
(check-eq? (say-no (apply-signature Image img4)) img4)

;; accepts composed images
(define img5 (overlay img1 img2))
(define img6 (beside img1 img2))
(define img7 (above img1 img2))
(check-eq? (say-no (apply-signature Image img5)) img5)
(check-eq? (say-no (apply-signature Image img6)) img6)
(check-eq? (say-no (apply-signature Image img7)) img7)

;; rejects non-image values
(check-equal? (say-no (apply-signature Image 42)) 'no)
(check-equal? (say-no (apply-signature Image "hello")) 'no)
(check-equal? (say-no (apply-signature Image #t)) 'no)
(check-equal? (say-no (apply-signature Image (list 1 2))) 'no)
(check-equal? (say-no (apply-signature Image (make-posn 1 2))) 'no)
(check-equal? (say-no (apply-signature Image (lambda (x) x))) 'no)

;; signature carries the name
(check-equal? (signature-name Image) 'Image)
