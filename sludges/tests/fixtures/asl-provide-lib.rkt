#lang htdp/asl

;; Fixture for asl-provide.rkt: a library module that exports typed
;; definitions with the provide that sludges re-exports.  ASL setters
;; cannot be provided (as in plain ASL), so a typed wrapper exports one.

(require sludges)

(define-type Age (integer-from 0))
(define-struct person [(name String) (age Age)])

(: birthday (Person -> Person))
(define (birthday p) (make-person (person-name p) (+ 1 (person-age p))))

(: set-age! (Person Age -> Void))
(define (set-age! p a) (set-person-age! p a))

(provide Age Person PersonOf make-person person? person-name person-age)
(provide birthday set-age!)
