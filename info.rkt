#lang info

(define collection 'multi)

;; Racket package versions are not semantic versions: `valid-version?` accepts
;; X.Y or X.Y.Z[.W], but rejects anything ending in `.0` beyond the two-component
;; form.  So 1.0 and 1.0.1 are fine, while 1.0.0 and 2.0.0 are not.
(define version "1.0")

(define deps
  '("base"
    "htdp-lib"
    "gui-lib"
    "errortrace-lib"
    "deinprogramm-signature"))

(define build-deps
  '("rackunit-lib"
    "scribble-lib"
    "racket-doc"
    "htdp-doc"))

(define pkg-desc
  "Extensions to signatures for HtDP student languages")

(define pkg-authors '("Carlo A. Furia"))

(define license 'GPL-3.0-or-later)
