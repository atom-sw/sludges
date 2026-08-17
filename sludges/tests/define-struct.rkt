#lang racket/base

(require rackunit
         (only-in lang/private/teach
                  intermediate-define-struct
                  signature ListOf ConsOf EmptyList
                  Integer Natural Number String Boolean)
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

;; ========================================
;; define-struct/typed: basic typed structs
;; ========================================

;; ----------------------------------------
;; Basic typed struct (all String fields)
;; ----------------------------------------

(define-struct/typed name [(first String) (last String)])

(define n1 (make-name "John" "Doe"))

;; constructor, predicate, accessors work
(check-true (name? n1))
(check-equal? (name-first n1) "John")
(check-equal? (name-last n1) "Doe")

;; Name signature enforces field types (not just predicate)
(check-eq? (say-no (apply-signature Name n1)) n1)
(check-equal? (say-no (apply-signature Name (make-name "Jane" "Smith")))
              (make-name "Jane" "Smith"))

;; rejects wrong field types
(check-equal? (say-no (apply-signature Name (make-name 42 "Doe"))) 'no)
(check-equal? (say-no (apply-signature Name (make-name "John" 42))) 'no)
(check-equal? (say-no (apply-signature Name (make-name 1 2))) 'no)

;; rejects non-name values
(check-equal? (say-no (apply-signature Name 42)) 'no)
(check-equal? (say-no (apply-signature Name "hello")) 'no)
(check-equal? (say-no (apply-signature Name #t)) 'no)

;; Name carries the struct name
(check-equal? (signature-name Name) 'name)

;; NameOf is still available
(define StrName (NameOf String String))
(check-eq? (say-no (apply-signature StrName n1)) n1)
(check-equal? (say-no (apply-signature StrName (make-name 1 2))) 'no)

;; ----------------------------------------
;; Typed struct with different field signatures
;; ----------------------------------------

(define-struct/typed record [(label String) (value Integer)])

(define r1 (make-record "x" 42))
(check-true (record? r1))
(check-equal? (record-label r1) "x")
(check-equal? (record-value r1) 42)

;; Record enforces field types
(check-eq? (say-no (apply-signature Record r1)) r1)
(check-equal? (say-no (apply-signature Record (make-record 42 42))) 'no)
(check-equal? (say-no (apply-signature Record (make-record "x" "y"))) 'no)
(check-equal? (say-no (apply-signature Record 42)) 'no)

;; ----------------------------------------
;; Typed struct with hyphenated name
;; ----------------------------------------

(define-struct/typed int-pair [(fst Integer) (snd Integer)])

(define ip1 (make-int-pair 10 20))
(check-true (int-pair? ip1))
(check-equal? (int-pair-fst ip1) 10)
(check-equal? (int-pair-snd ip1) 20)

;; IntPair enforces Integer on both fields
(check-eq? (say-no (apply-signature IntPair ip1)) ip1)
(check-equal? (say-no (apply-signature IntPair (make-int-pair 1.5 2))) 'no)
(check-equal? (say-no (apply-signature IntPair (make-int-pair 1 "x"))) 'no)
(check-equal? (say-no (apply-signature IntPair 42)) 'no)

;; signature name follows titlecase + remove hyphens
(check-equal? (signature-name IntPair) 'int-pair)

;; ----------------------------------------
;; Typed struct with Number fields
;; ----------------------------------------

(define-struct/typed coord [(x Number) (y Number)])

(define c1 (make-coord 1.5 2.5))
(check-true (coord? c1))
(check-equal? (coord-x c1) 1.5)
(check-equal? (coord-y c1) 2.5)

;; Coord enforces Number on both fields
(check-eq? (say-no (apply-signature Coord c1)) c1)
(check-equal? (say-no (apply-signature Coord (make-coord 1 2))) (make-coord 1 2))
(check-equal? (say-no (apply-signature Coord (make-coord "x" 2))) 'no)
(check-equal? (say-no (apply-signature Coord (make-coord 1 "y"))) 'no)
(check-equal? (say-no (apply-signature Coord 42)) 'no)

;; ----------------------------------------
;; Typed struct with Boolean field
;; ----------------------------------------

(define-struct/typed flag [(label String) (active Boolean)])

(define f1 (make-flag "test" #t))
(check-true (flag? f1))
(check-eq? (say-no (apply-signature Flag f1)) f1)
(check-equal? (say-no (apply-signature Flag (make-flag "x" #f)))
              (make-flag "x" #f))
(check-equal? (say-no (apply-signature Flag (make-flag "x" 42))) 'no)
(check-equal? (say-no (apply-signature Flag (make-flag 42 #t))) 'no)

;; ========================================
;; CoordOf still available for parametric use
;; ========================================

(define IntCoord (CoordOf Integer Integer))
(check-equal? (say-no (apply-signature IntCoord (make-coord 1 2))) (make-coord 1 2))
(check-equal? (say-no (apply-signature IntCoord (make-coord 1.5 2))) 'no)

;; ========================================
;; Compound signature forms in field positions
;; (ListOf, mixed, etc. inside define-struct)
;; ========================================

;; ----------------------------------------
;; ListOf in a struct field
;; ----------------------------------------

(define-struct/typed child [(name String)])
(define-struct/typed classroom [(teacher String) (students (ListOf Child))])

(define cr1 (make-classroom "Alice" '()))
(check-true (classroom? cr1))
(check-equal? (classroom-teacher cr1) "Alice")
(check-equal? (classroom-students cr1) '())

(define bob (make-child "Bob"))
(define carol (make-child "Carol"))
(define cr2 (make-classroom "Alice" (list bob carol)))
(check-equal? (classroom-students cr2) (list bob carol))

;; Violation: 42 is not a Child
(check-equal? (say-no (make-classroom "Alice" (list 42))) 'no)
;; Violation: "not-a-list" is not a (ListOf Child)
(check-equal? (say-no (make-classroom "Alice" "not-a-list")) 'no)
;; Correct: empty list satisfies (ListOf Child)
(check-equal? (say-no (make-classroom "Alice" '())) (make-classroom "Alice" '()))

;; ========================================
;; Recursive / forward-reference struct types
;; (no-arbitrary-sig prevents eager forcing)
;; ========================================

;; ----------------------------------------
;; Self-referential struct: ListOf with self-type in field
;; ----------------------------------------

(define-struct/typed person2 [(name String) (children (ListOf Person2))])

;; Construction works (no undefined-reference error)
(define p2a (make-person2 "Alice" '()))
(define p2b (make-person2 "Bob" (list p2a)))
(define p2c (make-person2 "Carol" (list p2a p2b)))
(check-true (person2? p2a))
(check-true (person2? p2b))
(check-equal? (person2-name p2a) "Alice")
(check-equal? (person2-children p2a) '())
(check-equal? (person2-name p2b) "Bob")
(check-equal? (person2-children p2b) (list p2a))

;; Person2 signature enforces field types
(check-eq? (say-no (apply-signature Person2 p2a)) p2a)
(check-eq? (say-no (apply-signature Person2 p2b)) p2b)
(check-equal? (say-no (apply-signature Person2 42)) 'no)
;; Wrong type for name field
(check-equal? (say-no (make-person2 42 '())) 'no)
;; Wrong type for children field (not a list)
(check-equal? (say-no (make-person2 "Alice" 42)) 'no)
;; Wrong element type in children list
(check-equal? (say-no (make-person2 "Alice" (list 42))) 'no)

;; ----------------------------------------
;; Forward reference via define-type + ListOf
;; ----------------------------------------

(define-type LOP3 (ListOf Person3))
(define-struct/typed person3 [(name String) (children LOP3)])

;; Construction works (no undefined-reference error)
(define p3a (make-person3 "Dave" '()))
(define p3b (make-person3 "Eve" (list p3a)))
(check-true (person3? p3a))
(check-true (person3? p3b))
(check-equal? (person3-name p3a) "Dave")
(check-equal? (person3-children p3a) '())
(check-equal? (person3-name p3b) "Eve")
(check-equal? (person3-children p3b) (list p3a))

;; Person3 signature enforces field types
(check-eq? (say-no (apply-signature Person3 p3a)) p3a)
(check-eq? (say-no (apply-signature Person3 p3b)) p3b)
(check-equal? (say-no (apply-signature Person3 42)) 'no)
;; Wrong type for name field
(check-equal? (say-no (make-person3 42 '())) 'no)
;; Wrong type for children field (not a list)
(check-equal? (say-no (make-person3 "Dave" 42)) 'no)
;; Wrong element type in children list
(check-equal? (say-no (make-person3 "Dave" (list 42))) 'no)

;; ----------------------------------------
;; one-of / ConsOf with self-type (existing pattern)
;; ----------------------------------------

(define-type LOP (one-of EmptyList (ConsOf Person LOP)))
(define-struct/typed person [(name String) (children LOP)])

(define pa (make-person "Frank" '()))
(define pb (make-person "Grace" (cons pa '())))
(check-true (person? pa))
(check-true (person? pb))
(check-equal? (person-name pa) "Frank")
(check-equal? (person-children pa) '())
(check-eq? (say-no (apply-signature Person pa)) pa)
(check-eq? (say-no (apply-signature Person pb)) pb)
(check-equal? (say-no (apply-signature Person 42)) 'no)
(check-equal? (say-no (make-person 42 '())) 'no)
