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
;; MouseEvent
;; ----------------------------------------

;; accepts valid mouse event strings
(check-eq? (say-no (apply-signature MouseEvent "button-down")) "button-down")
(check-eq? (say-no (apply-signature MouseEvent "button-up")) "button-up")
(check-eq? (say-no (apply-signature MouseEvent "drag")) "drag")
(check-eq? (say-no (apply-signature MouseEvent "move")) "move")
(check-eq? (say-no (apply-signature MouseEvent "enter")) "enter")
(check-eq? (say-no (apply-signature MouseEvent "leave")) "leave")

;; rejects invalid mouse event strings
(check-equal? (say-no (apply-signature MouseEvent "click")) 'no)
(check-equal? (say-no (apply-signature MouseEvent "hover")) 'no)
(check-equal? (say-no (apply-signature MouseEvent "")) 'no)

;; rejects non-string values
(check-equal? (say-no (apply-signature MouseEvent 42)) 'no)
(check-equal? (say-no (apply-signature MouseEvent #t)) 'no)
(check-equal? (say-no (apply-signature MouseEvent (list 1 2))) 'no)

;; signature carries the name
(check-equal? (signature-name MouseEvent) 'MouseEvent)

;; ----------------------------------------
;; KeyEvent
;; ----------------------------------------

;; accepts single-character key events
(check-eq? (say-no (apply-signature KeyEvent "a")) "a")
(check-eq? (say-no (apply-signature KeyEvent "Z")) "Z")
(check-eq? (say-no (apply-signature KeyEvent "1")) "1")
(check-eq? (say-no (apply-signature KeyEvent " ")) " ")

;; accepts named special key events
(check-eq? (say-no (apply-signature KeyEvent "left")) "left")
(check-eq? (say-no (apply-signature KeyEvent "right")) "right")
(check-eq? (say-no (apply-signature KeyEvent "up")) "up")
(check-eq? (say-no (apply-signature KeyEvent "down")) "down")
(check-eq? (say-no (apply-signature KeyEvent "escape")) "escape")
(check-eq? (say-no (apply-signature KeyEvent "shift")) "shift")
(check-eq? (say-no (apply-signature KeyEvent "f1")) "f1")

;; rejects invalid key event strings
(check-equal? (say-no (apply-signature KeyEvent "")) 'no)
(check-equal? (say-no (apply-signature KeyEvent "not-a-key")) 'no)
(check-equal? (say-no (apply-signature KeyEvent "ab")) 'no)

;; rejects non-string values
(check-equal? (say-no (apply-signature KeyEvent 42)) 'no)
(check-equal? (say-no (apply-signature KeyEvent #t)) 'no)
(check-equal? (say-no (apply-signature KeyEvent (list 1 2))) 'no)

;; signature carries the name
(check-equal? (signature-name KeyEvent) 'KeyEvent)
