#lang htdp/isl+

;; Fixture for isl-provide.rkt: a library module that exports typed
;; definitions with the provide that sludges re-exports.

(require sludges)

(define-type Age (integer-from 0))
(define-struct person [(name String) (age Age)])

(: birthday (Person -> Person))
(define (birthday p) (make-person (person-name p) (+ 1 (person-age p))))

(provide Age Person PersonOf make-person person? person-name person-age)
(provide birthday)
