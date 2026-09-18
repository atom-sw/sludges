#lang racket/base

;; sludges: Extensions to HtDP student languages signatures

(require (only-in lang/private/signature-syntax mixed signature predicate combined)
         (only-in lang/posn posn? posn-x posn-y)
         (only-in mrlib/image-core image?)
         racket/lazy-require
         racket/promise
         deinprogramm/signature/signature-english
         (only-in deinprogramm/signature/signature
                  apply-signature make-signature signature?
                  signature-name signature-enforcer signature-syntax
                  signature-info-promise signature-<=?-proc signature-=?-proc
                  signature-violation-proc
                  call-with-signature-violation-proc
                  signature-violation)
         ;; All three define-struct variants, for language-appropriate delegation.
         ;; beginner:     first-order? #t, setters? #f  (BSL, BSL+)
         ;; intermediate: first-order? #f, setters? #f  (ISL, ISL+)
         ;; advanced:     first-order? #f, setters? #t  (ASL)
         (only-in lang/private/teach
                   beginner-define-struct
                   intermediate-define-struct
                   advanced-define-struct
                   signature ListOf Any False ConsOf)
         (only-in lang/private/set-result set!-result)
         (only-in errortrace/marks-to-context
                  errortrace-continuation-mark-set->context)
         (only-in setup/collects path->collects-relative)
         (prefix-in te:
                    (only-in test-engine/test-engine
                             signature-violation
                             signature-violation-obj
                             signature-violation-signature
                             signature-violation-message
                             signature-violation-blame-srcloc
                             current-test-object
                             test-object-signature-violations
                             set-test-object-signature-violations!))
         (for-syntax racket/base
                     racket/list
                     racket/string
                     (only-in lang/private/firstorder
                              first-order->higher-order)
                     (only-in lang/private/teachhelp
                              make-first-order-function)))



;; # Lifted Signatures

;; A type constructor such as PosnOf, ConsOf or Add1 denotes the image of a
;; value constructor: (PosnOf X Y) describes the values (make-posn x y) with x
;; in X and y in Y.  Checking membership never calls the constructor, it
;; inverts it:
;;
;;   v belongs to (C S1 ... Sn)  iff  (recognizer v), and
;;                                    (selector-i v) belongs to Si, for every i
;;
;; which is exactly a combined signature of one predicate plus one property per
;; argument.  make-lifted-signature builds that combination; PosnOf, Add1 and
;; every constructor introduced by define-type-constructor go through it.
;;
;; Two properties of this encoding matter to whoever lifts a constructor:
;;
;;   * Checking is eager and deep.  make-property-signature discards the
;;     enforced sub-value, so violations fire when the signature is applied
;;     rather than when a selector is later called.  ConsOf, which DeinProgramm
;;     builds on lazy wraps instead, behaves the other way round.
;;
;;   * A recursive type terminates only if the recognizer makes the selectors
;;     strictly decreasing.  Lifting add1 with the recognizer number? and the
;;     selector sub1, for instance, descends forever on 1.5; the recognizer of
;;     Add1 below rules that out.
;;
;; name names the signature; #:expected names the type a violation message asks
;; for, which differs from name only where the two have historically differed,
;; as in PosnOf.  The outer make-signature wrapper intercepts violations from
;; the inner combined signature and re-fires them with self (which inherits proper
;; syntax from the teaching language's make-call-signature) and a
;; pre-formatted message including the field type name.  Without this
;; wrapper, violations would show `main.rkt` as the blame location
;; (from the property-signature syntax objects) instead of the user's
;; source file.
(define (make-lifted-signature name recognizer selectors sigs
                               #:expected [expected-name name])
  (unless (= (length selectors) (length sigs))
    (error name "expected ~a type argument(s), but got ~a"
           (length selectors) (length sigs)))
  (let* ([inner
          (make-combined-signature
           name
           (cons (make-predicate-signature #f (delay recognizer) #f)
                 (map (lambda (selector sig)
                        (make-property-signature (signature-name sig)
                                                 selector sig #'lifted-signature))
                      selectors sigs))
           #'parametric-signature)]
         [outer
          (make-signature
           name
           (lambda (self obj)
             (let ([old-proc (signature-violation-proc)])
               ((let/ec exit
                  (call-with-signature-violation-proc
                   (lambda (o s m b)
                     (exit (lambda ()
                             (old-proc o self
                                       (or m (expected-message (signature-name s) expected-name o))
                                       b)
                             obj)))
                   (lambda ()
                     (let ([r ((signature-enforcer inner) inner obj)])
                       (lambda () r))))))))
           (delay (signature-syntax inner))
           #:info-promise (signature-info-promise inner)
           #:=?-proc (signature-=?-proc inner)
           #:<=?-proc (signature-<=?-proc inner))])
    outer))

;; "expected a Posn, but got 3".  inner-name is the name of the signature that
;; actually fired, and is #f for an unnamed one, in which case the name of the
;; lifted constructor stands in.
(define (expected-message inner-name fallback-name obj)
  (let ([name (or inner-name fallback-name)])
    (format "expected ~a ~a, but got ~e"
            (if (memv (char-downcase (string-ref (format "~a" name) 0))
                      '(#\a #\e #\i #\o #\u))
                "an" "a")
            name obj)))



;; # Predefined Signatures


;; ## Posn and PosnOf signatures

;; Posn: non-parametric signature, checks (posn? x)
(define Posn (signature Posn (predicate posn?)))

;; PosnOf: parametric signature, checks (posn? x) and field signatures.
(define (PosnOf x-sig y-sig)
  (make-lifted-signature 'Posn posn? (list posn-x posn-y) (list x-sig y-sig)
                         #:expected 'PosnOf))


;; ## Image signature

;; Image: non-parametric signature, checks (image? x)
;; image? is originally from mrlib/image-core, which recognises all 2htdp/image values.
(define Image (signature Image (predicate image?)))


;; ## MouseEvent and KeyEvent signatures

;; mouse-event? and key-event? are defined in 2htdp/universe.
;; We use lazy require to avoid loading the full universe library
;; (with its GUI dependencies) until a signature is actually applied.
(lazy-require [2htdp/universe (mouse-event? key-event?)])

(define MouseEvent (signature MouseEvent (predicate mouse-event?)))
(define KeyEvent (signature KeyEvent (predicate key-event?)))


;; ## List signature

;; List: a list of any values, synonym for (ListOf Any).
(define List (signature List (ListOf Any)))


;; ## Maybe parametric signature

;; (Maybe T): either a value satisfying T, or #false.
;;
;; The outer make-signature wrapper intercepts violations from the inner
;; mixed signature and re-fires them with a pre-formatted message that
;; includes the 'Maybe name.  Without this wrapper, the teaching
;; language's make-call-signature would pass its own self (with name #f)
;; to the inner enforcer, causing violations to lose the 'Maybe name
;; and bypass the enhanced error message handler.
(define (Maybe T)
  (let* ([inner (make-mixed-signature 'Maybe (list T False) #f)]
         [outer
          (make-signature
           'Maybe
           (lambda (self obj)
             (let ([old-proc (signature-violation-proc)])
               ((let/ec exit
                  (call-with-signature-violation-proc
                   (lambda (o s m b)
                     (exit (lambda ()
                             (old-proc o self
                                       (or m (format "expected a Maybe, but got ~e" o))
                                       b)
                             obj)))
                   (lambda ()
                     (let ([r ((signature-enforcer inner) inner obj)])
                       (lambda () r))))))))
           (delay #f)
           #:info-promise (signature-info-promise inner)
           #:=?-proc (signature-=?-proc inner)
           #:<=?-proc (signature-<=?-proc inner))])
    outer))


;; ## Cons signature

;; Cons: an alias of the student languages' ConsOf.
;;
;; A function lifted to a type constructor keeps its name, capitalized, as Add1
;; capitalizes add1.  Cons is a faithful lift, where Add1 is not: it describes
;; every value cons builds.  ConsOf remains available and the
;; two are interchangeable, including inside the fold below, which recognizes
;; either spelling.
(define Cons ConsOf)


;; ## Add1 parametric signature

;; (Add1 T): a positive exact integer whose predecessor satisfies T.  It exists
;; so that the natural numbers can be described by the recursion that defines
;; them:
;;
;;   (define-type Natural (one-of (enum 0) (Add1 Natural)))
;;
;; Add1 is add1 with its domain restricted to the nonnegative exact integers:
;; the recognizer accepts v when v > 0, so the predecessor sub1(v) handed to T
;; is nonnegative, and the values Add1 describes are the positive exact
;; integers.
;;
;; So Add1 is not a faithful lift of add1 the way Cons is of cons: add1 also
;; accepts -5 and 1.5.  No faithful lift is possible here, because checking v
;; against (Add1 T) checks sub1(v) against T, so a recursive type descends by
;; sub1 until it reaches its base case, and nothing in Add1 can see where that
;; base case is.  Widening the recognizer makes Natural above diverge instead
;; of answering:
;;
;;   recognizer              0    3    -1      1.5     -4
;;   exact-integer? and > 0  0    3    reject  reject  reject
;;   exact-integer?          0    3    HANGS   reject  HANGS
;;   number? (add1's domain) 0    3    HANGS   HANGS   HANGS
;;
;; -1 is exactly what one types when testing a function on naturals, so Add1
;; buys a total check at the price of a narrower domain than add1.
;;
;; The restriction is worth naming.  Every base case at or above zero works,
;; including (one-of (enum 1) (Add1 Pos)) and the nested
;; (one-of (enum 0) (Add1 (Add1 Even))).  A negative base case does not:
;; (one-of (enum -5) (Add1 T)) accepts only -5 and rejects -4, -1, 0 and 3,
;; which do belong to the set it describes.  For those, use integer-from or
;; integer-from-to, or build a constructor with the floor you need using
;; define-type-constructor.  And (Add1 Integer) describes the positive
;; integers rather than every integer.
(define (Add1 T)
  (make-lifted-signature 'Add1
                         (lambda (v) (and (exact-integer? v) (> v 0)))
                         (list sub1)
                         (list T)))


;; ## Vector and VectorOf signatures

;; Vector: any vector, equivalent to (predicate vector?).
;; Intended for ASL, where vectors are part of the language.
(define Vector (signature Vector (predicate vector?)))

;; (VectorOf T): a vector whose every element satisfies T.
;; Same violation-interception wrapper as Maybe, see comment there.
(define (VectorOf T)
  (let* ([inner (make-vector-signature 'VectorOf T #f)]
         [outer
          (make-signature
           'VectorOf
           (lambda (self obj)
             (let ([old-proc (signature-violation-proc)])
               ((let/ec exit
                  (call-with-signature-violation-proc
                   (lambda (o s m b)
                     (exit (lambda ()
                             (old-proc o self
                                       (or m (format "expected a VectorOf, but got ~e" o))
                                       b)
                             obj)))
                   (lambda ()
                     (let ([r ((signature-enforcer inner) inner obj)])
                       (lambda () r))))))))
           (delay #f)
           #:info-promise (signature-info-promise inner)
           #:=?-proc (signature-=?-proc inner)
           #:<=?-proc (signature-<=?-proc inner))])
    outer))


;; ## Void signature

;; Void: accepts both Racket's (void) and the teaching-language set!-result singleton.
;; In HtDP teaching languages, set! / vector-set! return an opaque
;; set!-result struct (not true void) so the REPL can display it as (void)
;; while suppressing real void values.  This signature accepts both.
;; Intended for ASL, where set! and other state-changing functions are available.
(define Void
  (signature Void (predicate (lambda (x) (or (void? x) (eq? x set!-result))))))



;; # Interval Signatures
;;
;; Integer intervals (bounds always inclusive, w.l.o.g for integers):
;;   (integer-from-to lo hi)  → [lo, hi]
;;   (integer-from lo)        → [lo, +∞)
;;   (integer-to hi)          → (-∞, hi]
;;
;; Real-number bounded intervals (< in name signals open/excluded endpoint):
;;   (number-from-to lo hi)   → [lo, hi]   (both closed)
;;   (number-from<-to lo hi)  → (lo, hi]   (lo open, hi closed)
;;   (number-from-<to lo hi)  → [lo, hi)   (lo closed, hi open)
;;   (number-from<-<to lo hi) → (lo, hi)   (both open)
;;
;; Real-number unbounded intervals:
;;   (number-from lo)         → [lo, +∞)   (closed lo)
;;   (number-from< lo)        → (lo, +∞)   (open lo)
;;   (number-to hi)           → (-∞, hi]   (closed hi)
;;   (number-<to hi)          → (-∞, hi)   (open hi)


;; ## Integer intervals

(define (integer-from-to lo hi)
  (unless (integer? lo)
    (error 'integer-from-to "lower bound must be an integer, given ~e" lo))
  (unless (integer? hi)
    (error 'integer-from-to "upper bound must be an integer, given ~e" hi))
  (unless (<= lo hi)
    (error 'integer-from-to "lower bound ~e must be <= upper bound ~e" lo hi))
  (make-predicate-signature 'integer-from-to
    (delay (lambda (n) (and (integer? n) (<= lo n) (<= n hi))))
    #f))

(define (integer-from lo)
  (unless (integer? lo)
    (error 'integer-from "lower bound must be an integer, given ~e" lo))
  (make-predicate-signature 'integer-from
    (delay (lambda (n) (and (integer? n) (<= lo n))))
    #f))

(define (integer-to hi)
  (unless (integer? hi)
    (error 'integer-to "upper bound must be an integer, given ~e" hi))
  (make-predicate-signature 'integer-to
    (delay (lambda (n) (and (integer? n) (<= n hi))))
    #f))


;; ## Real-number bounded intervals

(define (number-from-to lo hi)
  (unless (real? lo)
    (error 'number-from-to "lower bound must be a real number, given ~e" lo))
  (unless (real? hi)
    (error 'number-from-to "upper bound must be a real number, given ~e" hi))
  (unless (<= lo hi)
    (error 'number-from-to "lower bound ~e must be <= upper bound ~e" lo hi))
  (make-predicate-signature 'number-from-to
    (delay (lambda (n) (and (real? n) (<= lo n) (<= n hi))))
    #f))

(define (number-from<-to lo hi)
  (unless (real? lo)
    (error 'number-from<-to "lower bound must be a real number, given ~e" lo))
  (unless (real? hi)
    (error 'number-from<-to "upper bound must be a real number, given ~e" hi))
  (unless (< lo hi)
    (error 'number-from<-to "lower bound ~e must be < upper bound ~e (open lower endpoint)" lo hi))
  (make-predicate-signature 'number-from<-to
    (delay (lambda (n) (and (real? n) (< lo n) (<= n hi))))
    #f))

(define (number-from-<to lo hi)
  (unless (real? lo)
    (error 'number-from-<to "lower bound must be a real number, given ~e" lo))
  (unless (real? hi)
    (error 'number-from-<to "upper bound must be a real number, given ~e" hi))
  (unless (< lo hi)
    (error 'number-from-<to "lower bound ~e must be < upper bound ~e (open upper endpoint)" lo hi))
  (make-predicate-signature 'number-from-<to
    (delay (lambda (n) (and (real? n) (<= lo n) (< n hi))))
    #f))

(define (number-from<-<to lo hi)
  (unless (real? lo)
    (error 'number-from<-<to "lower bound must be a real number, given ~e" lo))
  (unless (real? hi)
    (error 'number-from<-<to "upper bound must be a real number, given ~e" hi))
  (unless (< lo hi)
    (error 'number-from<-<to "lower bound ~e must be < upper bound ~e (both endpoints open)" lo hi))
  (make-predicate-signature 'number-from<-<to
    (delay (lambda (n) (and (real? n) (< lo n) (< n hi))))
    #f))


;; ## Real-number unbounded intervals

(define (number-from lo)
  (unless (real? lo)
    (error 'number-from "lower bound must be a real number, given ~e" lo))
  (make-predicate-signature 'number-from
    (delay (lambda (n) (and (real? n) (<= lo n))))
    #f))

(define (number-from< lo)
  (unless (real? lo)
    (error 'number-from< "lower bound must be a real number, given ~e" lo))
  (make-predicate-signature 'number-from<
    (delay (lambda (n) (and (real? n) (< lo n))))
    #f))

(define (number-to hi)
  (unless (real? hi)
    (error 'number-to "upper bound must be a real number, given ~e" hi))
  (make-predicate-signature 'number-to
    (delay (lambda (n) (and (real? n) (<= n hi))))
    #f))

(define (number-<to hi)
  (unless (real? hi)
    (error 'number-<to "upper bound must be a real number, given ~e" hi))
  (make-predicate-signature 'number-<to
    (delay (lambda (n) (and (real? n) (< n hi))))
    #f))



;; # Typed Struct Definitions


;; ## Helpers for define-struct

;; Boolean signature for predicate return type wrapping.
(define Boolean-sig (make-predicate-signature 'Boolean (delay boolean?) #f))

;; no-arbitrary-sig: wrap a signature with arbitrary-promise = (delay #f).
;; This blocks the eager forcing chain in StructOf (teach.rkt:1059), so that
;; forward references of struct signatures are possible.
;; Limitation: this lazy definition of signature types is incompatible
;;             with QuickCheck random generation (which we don't use in student languages).
(define (no-arbitrary-sig sig)
  (make-signature
   (signature-name sig)
   (signature-enforcer sig)
   (delay (signature-syntax sig))
   #:arbitrary-promise (delay #f)
   #:info-promise (signature-info-promise sig)
   #:<=?-proc (signature-<=?-proc sig)
   #:=?-proc (signature-=?-proc sig)))

;; wrap-struct-procs: given the rest-vals from the define-values body,
;;                    wrap all struct procedures with procedure signatures:
;;   constructor  : (Sig1 Sig2 ... -> StructSig)
;;   predicate    : (Any -> Boolean)
;;   selector_i   : (StructSig -> Sig_i)
;;
;; proc-name-syms  : (listof symbol?) — names for all proc names
;;                    order: (make-X X? X-f1 ... X-fN [set-X-f1! ...])
;; field-sigs      : (listof signature?) one per field
;; struct-sig      : signature? the struct type signature
;; num-fields      : exact-nonneg-integer?
;; rest-vals       : list? the remaining values from the define-values body
;;                    layout: [tmp1...tmpN make-X X? X-f1...X-fN ...]
(define (wrap-struct-procs proc-name-syms field-sigs struct-sig
                           num-fields rest-vals)
  (define ctor-idx num-fields)
  (define pred-idx (+ num-fields 1))
  (define sel-start (+ num-fields 2))
  ;; Wrap constructor: (field-sigs -> struct-sig)
  (define ctor-name (car proc-name-syms))
  (define wrapped-ctor
    (apply-signature
     (make-procedure-signature ctor-name field-sigs struct-sig #f)
     (list-ref rest-vals ctor-idx)))
  ;; Wrap predicate: (Any -> Boolean)
  (define pred-name (cadr proc-name-syms))
  (define wrapped-pred
    (apply-signature
     (make-procedure-signature pred-name (list Any) Boolean-sig #f)
     (list-ref rest-vals pred-idx)))
  ;; Wrap selectors: (struct-sig -> field-sig_i)
  (define sel-names (cddr proc-name-syms))
  (define wrapped-sels
    (let loop ([i 0] [names sel-names] [sigs field-sigs])
      (if (or (null? names) (= i num-fields))
          '()
          (cons (apply-signature
                 (make-procedure-signature (car names)
                                           (list struct-sig)
                                           (car sigs)
                                           #f)
                 (list-ref rest-vals (+ sel-start i)))
                (loop (+ i 1) (cdr names) (cdr sigs))))))
  ;; Rebuild rest-vals with wrapped procs replacing originals.
  ;; Positions: [0..ctor-idx-1] unchanged (tmp vals),
  ;;            ctor-idx, pred-idx, sel-start..sel-start+N-1 replaced,
  ;;            everything after (ASL setters) unchanged.
  (let loop ([i 0] [vals rest-vals])
    (cond
      [(null? vals) '()]
      [(= i ctor-idx) (cons wrapped-ctor (loop (+ i 1) (cdr vals)))]
      [(= i pred-idx) (cons wrapped-pred (loop (+ i 1) (cdr vals)))]
      [(and (>= i sel-start) (< i (+ sel-start num-fields)))
       (cons (list-ref wrapped-sels (- i sel-start))
             (loop (+ i 1) (cdr vals)))]
      [else (cons (car vals) (loop (+ i 1) (cdr vals)))])))


;; ## define-struct/typed

;; define-struct/typed: define a struct with typed fields.
;; All fields must have signatures.
;; (define-struct/typed name [(f1 Sig1) (f2 Sig2)])
;; Delegates to intermediate-define-struct, then rewrites the
;; Name signature to be (NameOf Sig1 Sig2).
(define-syntax (define-struct/typed stx)
  (syntax-case stx ()
    [(_ name ((field-name field-sig) ...))
     (and (identifier? #'name)
          (andmap identifier? (syntax->list #'(field-name ...))))
     (expand-typed-struct stx #'name #'(field-name ...) #'(field-sig ...))]))


;; ## define-struct

;; define-struct:  shadows native define-struct  and delegates to
;; native or typed variants:
;;   (define-struct name (f1 f2 f3))                — untyped/native
;;   (define-struct name [(f1 Sig1) (f2 Sig2)])     — typed
;;
;; Untyped: delegates to the language-appropriate native define-struct
;; (beginner, intermediate, or advanced) so that error messages, first-order
;; wrapping, setters, and all other language-specific behavior are preserved.
;;
;; Typed: uses the define-struct/typed logic (intermediate-define-struct +
;; expansion surgery + conditional first-order wrappers).
(define-syntax (define-struct stx)
  (syntax-case stx ()
    [(_ name (field-spec ...))
     (identifier? #'name)
     (let ([specs (syntax->list #'(field-spec ...))])
       (cond
         ;; All bare identifiers → untyped, delegate to native define-struct
         [(andmap identifier? specs)
          (cond
            [(bsl-context? stx)
             (datum->syntax stx
                            (syntax-e #'(beginner-define-struct name (field-spec ...)))
                            stx stx)]
            [(asl-context? stx)
             (datum->syntax stx
                            (syntax-e #'(advanced-define-struct name (field-spec ...)))
                            stx stx)]
            [else
             (datum->syntax stx
                            (syntax-e #'(intermediate-define-struct name (field-spec ...)))
                            stx stx)])]
         ;; All two-element lists with identifier first → typed
         [(andmap (lambda (spec)
                    (syntax-case spec ()
                      [(fname fsig) (identifier? #'fname) #t]
                      [_ #f]))
                  specs)
          ;; Extract field names and signatures, then use typed struct logic.
          ;; Pass stx (the define-struct call site) for correct lexical context.
          (let-values ([(fnames fsigs)
                        (let loop ([ss specs] [ns '()] [ts '()])
                          (if (null? ss)
                              (values (reverse ns) (reverse ts))
                              (syntax-case (car ss) ()
                                [(fn fs) (loop (cdr ss)
                                               (cons #'fn ns)
                                               (cons #'fs ts))])))])
            (expand-typed-struct stx #'name
                                (datum->syntax stx fnames stx)
                                (datum->syntax stx fsigs stx)))]
         ;; Otherwise: malformed — delegate to native define-struct
         ;; so the student gets the native error messages.
         [else
          (cond
            [(bsl-context? stx)
             (datum->syntax stx
                            (syntax-e #'(beginner-define-struct name (field-spec ...)))
                            stx stx)]
            [(asl-context? stx)
             (datum->syntax stx
                            (syntax-e #'(advanced-define-struct name (field-spec ...)))
                            stx stx)]
            [else
             (datum->syntax stx
                            (syntax-e #'(intermediate-define-struct name (field-spec ...)))
                            stx stx)])]))]
    ;; No field list or bad shape — delegate to native for error messages
    [(_ . rest)
     (cond
       [(bsl-context? stx)
        (datum->syntax stx
                       (cons #'beginner-define-struct #'rest)
                       stx stx)]
       [(asl-context? stx)
        (datum->syntax stx
                       (cons #'advanced-define-struct #'rest)
                       stx stx)]
       [else
        (datum->syntax stx
                       (cons #'intermediate-define-struct #'rest)
                       stx stx)])]))



;; # Mixed Signatures: one-of

;; one-of is an alias for mixed (union of signatures)
(define-syntax one-of (make-rename-transformer #'mixed))



;; # Named Type Definitions: define-type

;; define-type is a shorthand for defining a named signature
;; (define-type TypeName body) expands to (define TypeName (signature TypeName body))
;; (define-type (TypeName p ...) body) expands to
;;   (define (TypeName p ...) (signature TypeName body))
;;
;; Special handling for (predicate f): in BSL/BSL+, functions are not first class;
;; hence, the predicate signature form is effectively unusable in BSL/BSL+.
;; As a workaround, define-type looks for usages predicate, and applies
;; first-order->higher-order to lift the first-order restriction,
;; yielding the function as a value.
;; This transformation is applied regardless of the used student language: since
;; functions are already first-class in ISL/ISL+/ASL, first-order->higher-order
;; is an identity in those languages, and hence the transformation is harmless.
;; ## Diagnosing a head that is not a type constructor

;; The head of a type form must be a function from signatures to a signature:
;; ConsOf, ListOf, Maybe, PosnOf, Add1, or a constructor introduced by
;; define-type-constructor.  parse-signature accepts any identifier there and
;; delays the call, so an ordinary function like cons or add1 passes unnoticed
;; and then fails deep inside DeinProgramm the first time the signature is
;; enforced, with a message that mentions neither the type nor the source line.
;;
;; define-type therefore probes each such head at definition time: it calls it
;; on Any arguments and checks that the result is a signature.  A head that is
;; not bound yet is left alone, so a type may still refer forward to a
;; constructor defined further down the file.
;; The pair entries point at Cons rather than at its other name ConsOf, so
;; that the suggestion is the capitalization of what the user just wrote.
(define type-constructor-hints
  (hasheq 'cons "Cons" 'add1 "Add1" 'list "ListOf" 'make-posn "PosnOf"
          'vector "VectorOf" 'first "Cons" 'rest "Cons" 'car "Cons"
          'cdr "Cons" 'make-vector "VectorOf"))

;; Types being probed right now.  A parametric type is recursive through a call
;; form, as in (define-type (ListOfT T) (one-of EmptyList (ConsOf T (ListOfT T)))),
;; and its checks sit in the function body, so probing a head would re-enter the
;; very definition that is being checked.  Mutually recursive parametric types
;; do the same through one another.  A type already under probe is skipped.
(define types-being-probed (make-parameter '()))

(define (check-type-constructor! type-name head-name probe where)
  (define result
    (if (memq type-name (types-being-probed))
        'skipped
        (parameterize ([types-being-probed (cons type-name (types-being-probed))])
          (with-handlers ([exn:fail:contract:variable? (lambda (e) 'unbound)]
                          [exn:fail? (lambda (e) e)])
            (probe)))))
  (unless (or (eq? result 'unbound) (eq? result 'skipped) (signature? result))
    (error 'define-type
           "~a is not a type constructor, in the definition of ~a~a~a~a"
           head-name
           type-name
           (if where (format " (~a)" where) "")
           (let ([alt (hash-ref type-constructor-hints head-name #f)])
             (if alt (format "; use ~a instead" alt) ""))
           (if (exn:fail? result)
               (format "\n  calling ~a on a signature failed: ~a"
                       head-name (exn-message result))
               (format "\n  calling ~a on a signature returned ~e, not a signature"
                       head-name result)))))


(define-syntax (define-type stx)
  (syntax-case stx (predicate)
    ;; Parametric with predicate body
    [(_ (name param ...) (predicate f))
     (identifier? #'f)
     (with-syntax ([f-ho (first-order->higher-order #'f)])
       #'(define (name param ...) (signature name (predicate f-ho))))]
    ;; Simple with predicate body
    [(_ name (predicate f))
     (and (identifier? #'name) (identifier? #'f))
     (with-syntax ([f-ho (first-order->higher-order #'f)])
       #'(define name (signature name (predicate f-ho))))]
    ;; Parametric, general body: fold ConsOf prefixes, then expand
    ;; interval forms before wrapping in signature.
    ;;
	 ;; ## Wrapping with mixed, for better violation messages
	 ;;
    ;; When the folded result is a compound form (but not mixed), we
    ;; wrap it in (mixed ...) so that the top-level mixed enforcer
    ;; uses check-signature to catch inner violations and re-attributes
    ;; them to the named type with the original top-level value.
    ;; Without this wrapper, recursive types would lose the
    ;; type name in violation messages from inner unnamed components.
    ;;
    ;; Original mixed forms that collapse to a single alternative are
    ;; also re-wrapped for the same reason.
    ;;
    ;; When the folded result is STILL a mixed/one-of form, we use it
    ;; directly as (signature name body*), which passes name into parse-signature,
    ;; which creates a single mixed signature with the correct name AND
    ;; the user's source location.  An extra (mixed (mixed ...)) wrapper
    ;; would create two mixed signature objects: the outer one carrying
    ;; the macro template's source location (main.rkt) instead of the
    ;; user's code, causing a spurious duplicate violation pointing at
    ;; the teachpack internals.
    ;;
    ;; Non-mixed bodies (bare identifiers that denote type aliases, etc.)
	 ;; must NOT be wrapped. Since DeinProgramm's mixed =?-proc uses andmap without a
    ;; length guard, it crashes if it tries to compare mixed signatures
	 ;; of different length. Instead, we leave non-mixed as non-mixed, and
	 ;; normalize the length of mixed forms as described above.
    [(_ (name param ...) body)
     (with-syntax ([body* (expand-interval-forms (fold-consof-prefixes #'body) #'body)])
       (with-syntax ([(check ...) (type-constructor-checks #'body* #'name)])
         (cond
           ;; Folded body is still mixed/one-of, which can be used directly;
           ;; name is threaded through (signature name body*).
           [(mixed/one-of-form? #'body*)
            #'(define (name param ...) (begin check ... (signature name body*)))]
           ;; Original was mixed but folding collapsed to single alternative;
           ;; OR it's a compound form (not a bare identifier).
           ;; Wrap in (mixed ...) for better violation attribution.
           [(or (mixed/one-of-form? #'body)
                (and (not (identifier? #'body*)) (not (mixed/one-of-form? #'body*))))
            (with-syntax ([mixed-kw (datum->syntax #'body 'mixed #'body)])
              #'(define (name param ...) (begin check ... (signature name (mixed-kw body*)))))]
           ;; Non-mixed body (bare identifier, etc): use as is.
           [else
            #'(define (name param ...) (begin check ... (signature name body*)))])))]
    ;; Simple, general body; same mixed wrapping logic as parametric.
    [(_ name body)
     (with-syntax ([body* (expand-interval-forms (fold-consof-prefixes #'body) #'body)])
       (with-syntax ([(check ...) (type-constructor-checks #'body* #'name)])
         (cond
           [(mixed/one-of-form? #'body*)
            #'(define name (begin check ... (signature name body*)))]
           [(or (mixed/one-of-form? #'body)
                (and (not (identifier? #'body*)) (not (mixed/one-of-form? #'body*))))
            (with-syntax ([mixed-kw (datum->syntax #'body 'mixed #'body)])
              #'(define name (begin check ... (signature name (mixed-kw body*)))))]
           [else
            #'(define name (begin check ... (signature name body*)))])))]))



;; # Type Constructors: define-type-constructor

;; define-type-constructor introduces a new type constructor: a name that may
;; head a type form, the way ConsOf, PosnOf and Add1 do.
;;
;;   (define-type-constructor (name param ...) recognizer (selector ...))
;;
;; recognizer recognizes the values the constructor builds, and there is one
;; selector per parameter, recovering the corresponding component:
;;
;;   (define-type-constructor (Cons* first-sig rest-sig) cons? (first rest))
;;   (define-type List (one-of EmptyList (Cons* Any List)))
;;
;; The form expands to a plain function definition, so the name it binds is an
;; ordinary function from signatures to a signature, which is what the student
;; languages require of the head of a type form.
;;
;; recognizer and the selectors go through first-order->higher-order, so they
;; may be named as plain functions in BSL/BSL+, where functions are not first
;; class.  first-order->higher-order is the identity in ISL/ISL+/ASL.
;;
;; Two rules govern a correct constructor; make-lifted-signature explains both.
;; The recognizer must accept exactly the values the selectors can take apart,
;; and in a recursive type it must make the selectors strictly decreasing, or
;; checking the type will not terminate.
(define-syntax (define-type-constructor stx)
  (syntax-case stx ()
    [(_ (name param ...) recognizer (selector ...))
     (and (identifier? #'name)
          (identifier? #'recognizer)
          (andmap identifier? (syntax->list #'(param ...)))
          (andmap identifier? (syntax->list #'(selector ...))))
     (let ([params (syntax->list #'(param ...))]
           [selectors (syntax->list #'(selector ...))])
       (unless (= (length params) (length selectors))
         (raise-syntax-error 'define-type-constructor
           (format "expected one selector per parameter, but got ~a parameter(s) and ~a selector(s)"
                   (length params) (length selectors))
           stx))
       (with-syntax ([recognizer-ho (first-order->higher-order #'recognizer)]
                     [(selector-ho ...) (map first-order->higher-order selectors)])
         #'(define (name param ...)
             (make-lifted-signature 'name recognizer-ho
                                    (list selector-ho ...)
                                    (list param ...)))))]
    [(_ . _)
     (raise-syntax-error 'define-type-constructor
       "expected (define-type-constructor (name param ...) recognizer (selector ...)), where name, recognizer, the parameters and the selectors are all names"
       stx)]))



;; # Design Recipe Helpers: define-header and define-template

;; Students following the HtDP design recipe write a header (stub),
;; template, and implementation for each function, three successive
;; `define` forms for the same name.  Student languages reject
;; duplicate definitions, forcing students to comment out earlier
;; stages.  define-header and define-template expand to (void),
;; allowing all three stages to coexist.  Only the final `define`
;; (the implementation) creates the binding.
;;
;; Example:
;;   (: count (List -> Natural))
;;   (define-header (count lst) 0)
;;   (define-template (count lst)
;;     (cond [(empty? lst) ...]
;;           [(cons? lst) (... (first lst) ... (count (rest lst)) ...)]))
;;   (define (count lst)
;;     (cond [(empty? lst) 0]
;;           [(cons? lst) (+ 1 (count (rest lst)))]))

(define-syntax (define-header stx)
  (syntax-case stx ()
    [(_ (name arg ...) body)
     (identifier? #'name)
     #'(void)]
    [(_ . _)
     (raise-syntax-error 'define-header
       "expected (define-header (name arg ...) body)" stx)]))

(define-syntax (define-template stx)
  (syntax-case stx ()
    [(_ (name arg ...) body)
     (identifier? #'name)
     #'(void)]
    [(_ . _)
     (raise-syntax-error 'define-template
       "expected (define-template (name arg ...) body)" stx)]))



;; # Compile-time helpers

(begin-for-syntax


  ;; ## Language detection

  ;; Detect BSL/BSL+ context: check whether #%app in stx's lexical context
  ;; resolves to beginner-app from lang/private/teach.
  ;; We check via identifier-binding on (datum->syntax stx '#%app): in BSL/BSL+,
  ;; #%app is renamed from beginner-app, whose internal name is 'beginner-app'.
  ;; In ISL/ISL+/ASL, #%app is intermediate-app or similar.
  (define (bsl-context? stx)
    (let ([binding (identifier-binding (datum->syntax stx '#%app))])
      (and (list? binding)
           (eq? 'beginner-app (cadr binding)))))

  ;; Detect ASL context: check whether lambda in stx's lexical context
  ;; resolves to advanced-lambda.  ISL+ has intermediate-lambda instead.
  ;; BSL/BSL+ don't have lambda at all (identifier-binding returns #f).
  (define (asl-context? stx)
    (let ([binding (identifier-binding (datum->syntax stx 'lambda))])
      (and (list? binding)
           (eq? 'advanced-lambda (cadr binding)))))


  ;; ## define-type helpers

  ;; Does stx start with `mixed` or `one-of`?
  ;; Used by define-type to decide whether to wrap the body in (mixed ...)
  ;; for catch-and-rethrow violation attribution.
  (define (mixed/one-of-form? stx)
    (syntax-case stx ()
      [(head . _)
       (and (identifier? #'head)
            (memq (syntax-e #'head) '(mixed one-of)))
       #t]
      [_ #f]))

  ;; ### Collect type-constructor checks for a define-type body.
  ;;
  ;; Returns one (check-type-constructor! ...) form per call form in the body
  ;; whose head is not a keyword of the signature DSL, that is, per head that
  ;; is supposed to be a type constructor.  See the comments on
  ;; check-type-constructor! for what the check does and why.
  ;;
  ;; The walk recurses into the DSL forms whose operands are themselves
  ;; signatures (mixed/one-of, combined, and the signature of a property) and
  ;; into the operands of the call forms it checks.  It stays out of predicate,
  ;; enum, ListOf, VectorOf and procedure signatures: their operands are user
  ;; expressions, values, or types the student languages parse specially.  A
  ;; form containing -> is a procedure signature, whose head is an argument
  ;; type rather than a constructor.
  (define (type-constructor-checks body type-name)

    (define dsl-keywords
      '(mixed one-of enum predicate combined property ListOf VectorOf -> at signature))

    ;; "student.rkt:12:23", or #f when the form carries no source location.
    (define (form-location stx)
      (let ([src (syntax-source stx)]
            [line (syntax-line stx)]
            [col (syntax-column stx)])
        (and src line col
             (format "~a:~a:~a"
                     (if (path? src)
                         (let-values ([(base file dir?) (split-path src)])
                           (if (path? file) (path->string file) src))
                         src)
                     line col))))

    (define (make-check head args form)
      (with-syntax ([head-ho (first-order->higher-order head)]
                    [(any ...) (map (lambda (a) #'Any) args)]
                    [head-name (syntax-e head)]
                    [tname (syntax-e type-name)]
                    [where (form-location form)])
        #'(check-type-constructor! 'tname 'head-name
                                   (lambda () (head-ho any ...))
                                   where)))

    (define checks '())

    (define (walk stx)
      (syntax-case stx ()
        [(head arg ...)
         (identifier? #'head)
         (let ([sym (syntax-e #'head)]
               [args (syntax->list #'(arg ...))])
           (cond
             [(memq sym '(mixed one-of combined)) (for-each walk args)]
             [(eq? sym 'property)
              (when (= (length args) 2) (walk (cadr args)))]
             [(memq sym dsl-keywords) (void)]
             ;; (A B -> C): a procedure signature, not an application
             [(ormap (lambda (s) (and (identifier? s) (eq? (syntax-e s) '->)))
                     (cons #'head args))
              (void)]
             ;; a recursive reference to the type being defined, not a head
             ;; that could be checked
             [(eq? sym (syntax-e type-name)) (for-each walk args)]
             [else
              (set! checks (cons (make-check #'head args stx) checks))
              (for-each walk args)]))]
        [_ (void)]))

    (walk body)
    (reverse checks))

  ;; ### Normalize a define-type body.
  ;;   1. Fold ConsOf branches that share a common "car" signature in a mixed/one-of form.
  ;;   2. Wrap inner mixed instances of multiple ConsOf cdr in (combined ...).
  ;;
  ;; #### Normalization 1
  ;; This normalization avoids an issue with signature checking in the student languages,
  ;; which incorrectly rejects values when a mixed form contains multiple ConsOf
  ;; branches at different nesting depths.
  ;;
  ;; The transformation is semantically equivalent:
  ;;   (mixed (ConsOf A B) (ConsOf A C) X)
  ;;   ≡ (mixed (ConsOf A (mixed B C)) X)
  ;;
  ;; The function is applied recursively, so nested mixed forms are also
  ;; normalized.  Identifiers are compared by symbol name (since the body
  ;; is unexpanded student syntax and ConsOf / mixed are not imported into
  ;; the sludges module itself).
  ;;
  ;; The 'mixed keyword in the output is taken from the first occurrence in
  ;; the input (preserving whether the user wrote `mixed` or `one-of`).
  ;;
  ;; #### Normalization 2
  ;; When multiple ConsOf cdr branches are merged into a new inner mixed, that inner mixed is
  ;; wrapped in (combined ...).  This makes the inner mixed a "combined"
  ;; signature at runtime, which is opaque to DeinProgramm's
  ;; flatten-mixed-signatures and fold-lazy-wrap-signatures.  Without
  ;; this wrapper, recursive type references inside the inner mixed
  ;; resolve to mixed or lazy-wrap signatures that get inlined/merged
  ;; by DeinProgramm's normalisation passes.  The resulting alternative
  ;; counts can differ between structurally different types, and
  ;; DeinProgramm's signature=? for mixed uses andmap without checking
  ;; list lengths, crashing when the counts don't match.  The combined
  ;; wrapper prevents this by making the inner mixed opaque, so recursive
  ;; type references are neither inlined nor merged.
  (define (fold-consof-prefixes body)
    ;; Returns the symbol name of a syntax id, or #f if not an identifier.
    (define (id-sym stx)
      (and (identifier? stx) (syntax-e stx)))

    ;; Is this a mixed/one-of head?
    (define (mixed-head? stx)
      (memq (id-sym stx) '(mixed one-of)))

    ;; Is this a (ConsOf car cdr) form?  Cons is an alias of ConsOf, so a
    ;; student may have written either; branches spelled differently still
    ;; denote the same constructor and still fold together.
    (define (consof-form? stx)
      (syntax-case stx ()
        [(head a d) (memq (id-sym #'head) '(ConsOf Cons)) #t]
        [_ #f]))

    ;; Recursively fold a single alternative (which might itself be a mixed).
    (define (fold-alt alt)
      (syntax-case alt ()
        [(head . rest)
         (mixed-head? #'head)
         ;; Recurse into the mixed body
         (fold-mixed-alts #'head (syntax->list #'rest))]
        [_ alt]))

    ;; Given the mixed keyword stx and a list of alternative stx objects,
    ;; fold ConsOf branches by common car and rebuild.
    (define (fold-mixed-alts mixed-kw alts)
      ;; First recursively fold each alternative
      (define folded (map fold-alt alts))
      ;; Partition: collect (car-datum . cdr-stx) for ConsOf alts;
      ;; keep non-ConsOf alts as-is.
      ;; We use an association list to preserve insertion order of first
      ;; occurrence of each car-datum key.
      (define car-order '())   ; list of car-datum values in first-seen order
      (define car->cdrs (make-hash)) ; car-datum -> list of cdr stx (in order)
      (define non-consof '())  ; non-ConsOf alts, in order

      (for ([alt (in-list folded)])
        (if (consof-form? alt)
            (syntax-case alt ()
              [(hd a d)
               (let ([key (syntax->datum #'a)])
                 (if (hash-has-key? car->cdrs key)
                     (hash-set! car->cdrs key
                                (append (hash-ref car->cdrs key) (list #'d)))
                     (begin
                       ;; keep the head of the first branch of each group, so
                       ;; the rebuilt form is spelled the way the user wrote it
                       (set! car-order (append car-order (list (list key #'a #'hd))))
                       (hash-set! car->cdrs key (list #'d)))))])
            (set! non-consof (append non-consof (list alt)))))

      ;; Build the folded ConsOf alternatives
      (define consof-alts
        (for/list ([key+car-stx (in-list car-order)])
          (define car-stx (cadr key+car-stx))
          (define consof-kw (caddr key+car-stx))
          (define key (car key+car-stx))
          (define cdrs (hash-ref car->cdrs key))
          (if (= (length cdrs) 1)
              ;; Single entry: reconstruct (ConsOf car cdr)
              (datum->syntax mixed-kw
                             `(,consof-kw
                               ,car-stx
                               ,(car cdrs))
                             mixed-kw)
               ;; Multiple entries: fold into (ConsOf car (combined (mixed cdr1 cdr2 ...)))
               ;; First recursively fold the inner mixed, then wrap it in
               ;; (combined ...) to make it opaque to DeinProgramm's
               ;; flatten-mixed-signatures and fold-lazy-wrap-signatures.
               ;; Without this wrapper, recursive type references inside
               ;; the inner mixed get inlined/merged, producing different
               ;; numbers of alternatives for structurally different types,
               ;; which triggers issue 2 (andmap length mismatch in
               ;; signature=? for mixed signatures).
               (let* ([inner-mixed (datum->syntax mixed-kw
                                                  `(,mixed-kw ,@cdrs)
                                                  mixed-kw)]
                      [inner-folded (fold-alt inner-mixed)]
                      ;; Wrap the inner mixed in (combined ...) to prevent
                      ;; DeinProgramm from inlining/merging its alternatives.
                      [inner-wrapped
                       (datum->syntax mixed-kw
                                      `(,(datum->syntax mixed-kw 'combined mixed-kw)
                                        ,inner-folded)
                                      mixed-kw)])
                 (datum->syntax mixed-kw
                                `(,consof-kw
                                  ,car-stx
                                  ,inner-wrapped)
                                mixed-kw)))))

      ;; Combine: non-ConsOf alts first, then folded ConsOf alts.
      ;; (Ordering within each group is preserved; ConsOf groups come after
      ;; non-ConsOf alts to keep a predictable structure.)
      (define result-alts (append non-consof consof-alts))
      (cond
        [(= (length result-alts) 1) (car result-alts)]
        [else
         (datum->syntax mixed-kw
                        `(,mixed-kw ,@result-alts)
                        mixed-kw)]))

    ;; Entry point: only act on top-level mixed/one-of forms;
    ;; otherwise return body unchanged.
    ;;
    ;; Issue 2 (andmap length mismatch in signature=?) is handled inside
    ;; fold-mixed-alts: when multiple ConsOf cdrs are merged into a new
    ;; inner mixed, that mixed is wrapped in (combined ...).  This makes
    ;; the inner mixed opaque to DeinProgramm's flatten-mixed-signatures
    ;; and fold-lazy-wrap-signatures, preventing recursive type references
    ;; from being inlined/merged (which would produce different alternative
    ;; counts and trigger the crash).
    (syntax-case body ()
      [(head . rest)
       (mixed-head? #'head)
       (fold-mixed-alts #'head (syntax->list #'rest))]
      [_ body]))

  ;; Anchor syntax object carrying racket/base phase-0 bindings.
  ;; Used by expand-interval-forms so that generated identifiers (let,
  ;; lambda, unless, and, error, etc.) resolve to racket/base — not to
  ;; whatever student language the call-site happens to use.
  (define rb-ctx (quote-syntax racket-base-anchor))


  ;; ## Interval constructor helpers

  ;; Rewrite interval constructor calls inside define-type bodies into
  ;; (predicate ...) forms, so they are valid in the signature DSL.
  ;;
  ;; Standalone usage like (integer-from-to 0 6) passes through
  ;; parse-signature's (?signature-abstr ?signature ...) case, which tries
  ;; to parse arguments (0, 6) as sub-signatures — and fails.  By rewriting
  ;; the call into (predicate (let () <validation> (lambda (n) <test>))),
  ;; we produce a form that parse-signature handles natively.
  ;;
  ;; The rewrite recurses into DSL keywords (mixed, one-of, enum, combined,
  ;; property) but NOT into predicate bodies (those are user expressions).
  ;; Identifiers and other atomic forms are left unchanged.
  ;;
  ;; dsl-ctx — syntax object carrying the signature-DSL lexical context
  ;;           (from the define-type call site), used for `predicate` so
  ;;           that parse-signature recognises it.
  (define (expand-interval-forms body dsl-ctx)

    ;; Is stx a DSL keyword head (mixed/one-of, enum, combined, property)?
    ;; We recurse into these forms.  We do NOT include predicate, ListOf,
    ;; VectorOf, -> because their sub-expressions are not signature-DSL
    ;; forms (they are predicates, type parameters, or return types that
    ;; parse-signature handles specially).
    (define (dsl-recurse-head? stx)
      (and (identifier? stx)
           (memq (syntax-e stx) '(mixed one-of enum combined property))))

    ;; Build a (predicate (let () <checks> (lambda (n) <test>))) form.
    ;; ctx    — syntax object for source location
    ;; n-id   — syntax identifier for the lambda parameter
    ;; checks — list of syntax objects, each an (unless ...) form
    ;; test   — syntax object, the body of the lambda (references n-id)
    ;;
    ;; `predicate` gets dsl-ctx (student-language context) so that
    ;; parse-signature recognises the DSL keyword.
    ;; `let`, `lambda` get rb-ctx (racket/base context) so that
    ;; multi-body let and lambda work in all student languages.
    (define (make-pred-form ctx n-id checks test)
      (datum->syntax
       ctx
       `(,(datum->syntax dsl-ctx 'predicate ctx)
         (,(datum->syntax rb-ctx 'let ctx) ()
          ,@checks
          (,(datum->syntax rb-ctx 'lambda ctx) (,n-id) ,test)))
       ctx))

    ;; Build an (unless (pred arg) (error ...)) form.
    ;; All identifiers use rb-ctx (racket/base).
    (define (make-check ctx who pred arg msg)
      (datum->syntax
       ctx
       `(,(datum->syntax rb-ctx 'unless ctx)
         (,(datum->syntax rb-ctx pred ctx) ,arg)
         (,(datum->syntax rb-ctx 'error ctx)
          (,(datum->syntax rb-ctx 'quote ctx) ,who)
          ,(datum->syntax ctx msg ctx)
          ,arg))
       ctx))

    ;; Build an (unless (<= lo hi) (error ...)) form for range validation.
    ;; All identifiers use rb-ctx (racket/base).
    (define (make-range-check ctx who cmp lo hi msg)
      (datum->syntax
       ctx
       `(,(datum->syntax rb-ctx 'unless ctx)
         (,(datum->syntax rb-ctx cmp ctx) ,lo ,hi)
         (,(datum->syntax rb-ctx 'error ctx)
          (,(datum->syntax rb-ctx 'quote ctx) ,who)
          ,(datum->syntax ctx msg ctx)
          ,lo ,hi))
       ctx))

    ;; Try to rewrite a single interval form.  Returns rewritten syntax
    ;; or #f if stx is not a recognised interval form.
    (define (try-rewrite-interval stx)
      (syntax-case stx ()
        ;; --- integer-from-to lo hi ---
        [(head lo hi)
         (and (identifier? #'head) (eq? (syntax-e #'head) 'integer-from-to))
         (let ([n (datum->syntax stx (gensym 'n) stx)])
           (make-pred-form
            stx n
            (list (make-check stx 'integer-from-to 'integer? #'lo
                              "lower bound must be an integer, given ~e")
                  (make-check stx 'integer-from-to 'integer? #'hi
                              "upper bound must be an integer, given ~e")
                  (make-range-check stx 'integer-from-to '<= #'lo #'hi
                                   "lower bound ~e must be <= upper bound ~e"))
            (datum->syntax
             stx
             `(,(datum->syntax rb-ctx 'and stx)
               (,(datum->syntax rb-ctx 'integer? stx) ,n)
               (,(datum->syntax rb-ctx '<= stx) ,#'lo ,n)
               (,(datum->syntax rb-ctx '<= stx) ,n ,#'hi))
             stx)))]

        ;; --- integer-from lo ---
        [(head lo)
         (and (identifier? #'head) (eq? (syntax-e #'head) 'integer-from))
         (let ([n (datum->syntax stx (gensym 'n) stx)])
           (make-pred-form
            stx n
            (list (make-check stx 'integer-from 'integer? #'lo
                              "lower bound must be an integer, given ~e"))
            (datum->syntax
             stx
             `(,(datum->syntax rb-ctx 'and stx)
               (,(datum->syntax rb-ctx 'integer? stx) ,n)
               (,(datum->syntax rb-ctx '<= stx) ,#'lo ,n))
             stx)))]

        ;; --- integer-to hi ---
        [(head hi)
         (and (identifier? #'head) (eq? (syntax-e #'head) 'integer-to))
         (let ([n (datum->syntax stx (gensym 'n) stx)])
           (make-pred-form
            stx n
            (list (make-check stx 'integer-to 'integer? #'hi
                              "upper bound must be an integer, given ~e"))
            (datum->syntax
             stx
             `(,(datum->syntax rb-ctx 'and stx)
               (,(datum->syntax rb-ctx 'integer? stx) ,n)
               (,(datum->syntax rb-ctx '<= stx) ,n ,#'hi))
             stx)))]

        ;; --- number-from-to lo hi  [lo, hi] ---
        [(head lo hi)
         (and (identifier? #'head) (eq? (syntax-e #'head) 'number-from-to))
         (let ([n (datum->syntax stx (gensym 'n) stx)])
           (make-pred-form
            stx n
            (list (make-check stx 'number-from-to 'real? #'lo
                              "lower bound must be a real number, given ~e")
                  (make-check stx 'number-from-to 'real? #'hi
                              "upper bound must be a real number, given ~e")
                  (make-range-check stx 'number-from-to '<= #'lo #'hi
                                   "lower bound ~e must be <= upper bound ~e"))
            (datum->syntax
             stx
             `(,(datum->syntax rb-ctx 'and stx)
               (,(datum->syntax rb-ctx 'real? stx) ,n)
               (,(datum->syntax rb-ctx '<= stx) ,#'lo ,n)
               (,(datum->syntax rb-ctx '<= stx) ,n ,#'hi))
             stx)))]

        ;; --- number-from<-to lo hi  (lo, hi] ---
        [(head lo hi)
         (and (identifier? #'head) (eq? (syntax-e #'head) 'number-from<-to))
         (let ([n (datum->syntax stx (gensym 'n) stx)])
           (make-pred-form
            stx n
            (list (make-check stx '|number-from<-to| 'real? #'lo
                              "lower bound must be a real number, given ~e")
                  (make-check stx '|number-from<-to| 'real? #'hi
                              "upper bound must be a real number, given ~e")
                  (make-range-check stx '|number-from<-to| '< #'lo #'hi
                                   "lower bound ~e must be < upper bound ~e (open lower endpoint)"))
            (datum->syntax
             stx
             `(,(datum->syntax rb-ctx 'and stx)
               (,(datum->syntax rb-ctx 'real? stx) ,n)
               (,(datum->syntax rb-ctx '< stx) ,#'lo ,n)
               (,(datum->syntax rb-ctx '<= stx) ,n ,#'hi))
             stx)))]

        ;; --- number-from-<to lo hi  [lo, hi) ---
        [(head lo hi)
         (and (identifier? #'head) (eq? (syntax-e #'head) 'number-from-<to))
         (let ([n (datum->syntax stx (gensym 'n) stx)])
           (make-pred-form
            stx n
            (list (make-check stx '|number-from-<to| 'real? #'lo
                              "lower bound must be a real number, given ~e")
                  (make-check stx '|number-from-<to| 'real? #'hi
                              "upper bound must be a real number, given ~e")
                  (make-range-check stx '|number-from-<to| '< #'lo #'hi
                                   "lower bound ~e must be < upper bound ~e (open upper endpoint)"))
            (datum->syntax
             stx
             `(,(datum->syntax rb-ctx 'and stx)
               (,(datum->syntax rb-ctx 'real? stx) ,n)
               (,(datum->syntax rb-ctx '<= stx) ,#'lo ,n)
               (,(datum->syntax rb-ctx '< stx) ,n ,#'hi))
             stx)))]

        ;; --- number-from<-<to lo hi  (lo, hi) ---
        [(head lo hi)
         (and (identifier? #'head) (eq? (syntax-e #'head) '|number-from<-<to|))
         (let ([n (datum->syntax stx (gensym 'n) stx)])
           (make-pred-form
            stx n
            (list (make-check stx '|number-from<-<to| 'real? #'lo
                              "lower bound must be a real number, given ~e")
                  (make-check stx '|number-from<-<to| 'real? #'hi
                              "upper bound must be a real number, given ~e")
                  (make-range-check stx '|number-from<-<to| '< #'lo #'hi
                                   "lower bound ~e must be < upper bound ~e (both endpoints open)"))
            (datum->syntax
             stx
             `(,(datum->syntax rb-ctx 'and stx)
               (,(datum->syntax rb-ctx 'real? stx) ,n)
               (,(datum->syntax rb-ctx '< stx) ,#'lo ,n)
               (,(datum->syntax rb-ctx '< stx) ,n ,#'hi))
             stx)))]

        ;; --- number-from lo  [lo, +∞) ---
        [(head lo)
         (and (identifier? #'head) (eq? (syntax-e #'head) 'number-from))
         (let ([n (datum->syntax stx (gensym 'n) stx)])
           (make-pred-form
            stx n
            (list (make-check stx 'number-from 'real? #'lo
                              "lower bound must be a real number, given ~e"))
            (datum->syntax
             stx
             `(,(datum->syntax rb-ctx 'and stx)
               (,(datum->syntax rb-ctx 'real? stx) ,n)
               (,(datum->syntax rb-ctx '<= stx) ,#'lo ,n))
             stx)))]

        ;; --- number-from< lo  (lo, +∞) ---
        [(head lo)
         (and (identifier? #'head) (eq? (syntax-e #'head) '|number-from<|))
         (let ([n (datum->syntax stx (gensym 'n) stx)])
           (make-pred-form
            stx n
            (list (make-check stx '|number-from<| 'real? #'lo
                              "lower bound must be a real number, given ~e"))
            (datum->syntax
             stx
             `(,(datum->syntax rb-ctx 'and stx)
               (,(datum->syntax rb-ctx 'real? stx) ,n)
               (,(datum->syntax rb-ctx '< stx) ,#'lo ,n))
             stx)))]

        ;; --- number-to hi  (-∞, hi] ---
        [(head hi)
         (and (identifier? #'head) (eq? (syntax-e #'head) 'number-to))
         (let ([n (datum->syntax stx (gensym 'n) stx)])
           (make-pred-form
            stx n
            (list (make-check stx 'number-to 'real? #'hi
                              "upper bound must be a real number, given ~e"))
            (datum->syntax
             stx
             `(,(datum->syntax rb-ctx 'and stx)
               (,(datum->syntax rb-ctx 'real? stx) ,n)
               (,(datum->syntax rb-ctx '<= stx) ,n ,#'hi))
             stx)))]

        ;; --- number-<to hi  (-∞, hi) ---
        [(head hi)
         (and (identifier? #'head) (eq? (syntax-e #'head) '|number-<to|))
         (let ([n (datum->syntax stx (gensym 'n) stx)])
           (make-pred-form
            stx n
            (list (make-check stx '|number-<to| 'real? #'hi
                              "upper bound must be a real number, given ~e"))
            (datum->syntax
             stx
             `(,(datum->syntax rb-ctx 'and stx)
               (,(datum->syntax rb-ctx 'real? stx) ,n)
               (,(datum->syntax rb-ctx '< stx) ,n ,#'hi))
             stx)))]

        ;; Not an interval form
        [_ #f]))

    ;; Recursively walk body, rewriting interval forms and recursing
    ;; into DSL keyword bodies.
    (define (walk stx)
      (define rewritten (try-rewrite-interval stx))
      (cond
        [rewritten rewritten]
        [else
         (syntax-case stx ()
           ;; DSL keyword: recurse into sub-forms
           [(head sub ...)
            (dsl-recurse-head? #'head)
            (with-syntax ([(sub* ...) (map walk (syntax->list #'(sub ...)))])
              (datum->syntax stx (cons #'head (syntax->list #'(sub* ...))) stx))]
           ;; Anything else: leave unchanged
           [_ stx])]))

    (walk body))


  ;; ## Struct helpers

  ;; Replicate HtDP's struct-name->signature-name translation:
  ;; titlecase + remove hyphens.
  ;; Examples: posn -> Posn, my-posn -> MyPosn, color-2list -> Color2List
  (define (struct-name->signature-name-sym name-sym)
    (string->symbol
     (string-replace (string-titlecase (symbol->string name-sym))
                     "-" "")))

  ;; Given the struct name syntax, produce the Str signature name syntax
  (define (make-signature-name name-stx)
    (datum->syntax name-stx
                   (struct-name->signature-name-sym (syntax-e name-stx))
                   name-stx))

  ;; Given the struct name syntax, produce the StrOf parametric signature name syntax
  (define (make-parametric-signature-name name-stx)
    (datum->syntax name-stx
                   (struct-name->signature-name-sym
                    (string->symbol
                     (format "~a-of" (syntax-e name-stx))))
                   name-stx))

  ;; Generate first-order wrappers for struct procedure names.
  ;; Given the original proc-name identifiers from the define-values LHS,
  ;; the number of fields, and the macro call-site stx (for lexical context),
  ;; returns two values:
  ;;   - fresh-names: list of uninterned-symbol identifiers to replace the LHS
  ;;   - define-syntax-forms: list of (define-syntax ...) forms that wrap
  ;;     each original name with make-first-order-function
  ;;
  ;; The call-site-stx is needed so that the define-syntax bindings are
  ;; visible in the student module scope.
  ;;
  ;; IMPORTANT: The #%app passed to make-first-order-function must be
  ;; racket/base's #%app (i.e., #%plain-app), NOT the student language's
  ;; #%app (beginner-app).  The first-order wrapper rewrites (make-X ...)
  ;; to (#%app <uninterned> ...), and this must bypass beginner-app's checks
  ;; (which reject calls to module-defined variables).  This matches the
  ;; behavior of wrap-func-definitions in teach.rkt, where (quote-syntax #%app)
  ;; captures mzscheme's #%app, not beginner-app.
  ;;
  ;; proc-names order: (make-X X? X-f1 ... X-fN)
  ;; kinds:            constructor predicate selector ... selector
  ;; argcs:            N          1         1       ... 1
  (define (make-first-order-wrappers proc-name-stxs num-fields call-site-stx)
    (define kinds (list* 'constructor 'predicate
                         (map (lambda (_) 'selector) (cddr proc-name-stxs))))
    (define argcs (list* num-fields 1
                         (map (lambda (_) 1) (cddr proc-name-stxs))))
    (define fresh-names
      (for/list ([pn (in-list proc-name-stxs)])
        (datum->syntax pn
                       (string->uninterned-symbol
                        (symbol->string (syntax-e pn)))
                       pn)))
    (define def-syntax-forms
      (for/list ([orig-name (in-list proc-name-stxs)]
                 [fresh-name (in-list fresh-names)]
                 [kind (in-list kinds)]
                 [argc (in-list argcs)])
        ;; Use call-site-stx context for the orig-name in define-syntax,
        ;; so the binding is visible in the student module scope.
        (with-syntax ([visible-name (datum->syntax call-site-stx
                                                   (syntax-e orig-name)
                                                   orig-name)])
          ;; #%app here is racket/base's #%app (from our begin-for-syntax),
          ;; which is effectively #%plain-app — bypassing beginner-app.
          #`(define-syntax visible-name
              (make-first-order-function '#,kind
                                         #,argc
                                         (quote-syntax #,fresh-name)
                                         (quote-syntax #%app))))))
    (values fresh-names def-syntax-forms))

  ;; Rewrite expanded define-struct forms:
  ;; Walk the begin-wrapped expansion from local-expand, find the define-values
  ;; that binds Name and NameOf, and wrap its body so that the Name value
  ;; is replaced with (NameOf sig1 sig2 ...).
  ;;
  ;; When first-order? is #t (in BSL/BSL+), additionally replace the proc-name
  ;; identifiers on the define-values LHS with fresh uninterned symbols
  ;; and emit define-syntax wrappers that restrict bare identifier usage,
  ;; replicating what beginner-define-struct's wrap-func-definitions does.
  (define (rewrite-define-values expanded sig-name-stx sig-of-name-stx
                                 sig-exprs num-fields first-order?
                                 call-site-stx)
    (syntax-case expanded (begin)
      [(begin form ...)
       (datum->syntax expanded
                      (cons #'begin
                            (map (lambda (f)
                                   (rewrite-define-values
                                    f sig-name-stx sig-of-name-stx
                                    sig-exprs num-fields first-order?
                                    call-site-stx))
                                 (syntax->list #'(form ...))))
                      expanded
                      expanded)]
      [(dv (id0 id1 rest-ids ...) body)
       (and (free-identifier=? #'dv #'define-values)
            (bound-identifier=? #'id0 sig-name-stx)
            (bound-identifier=? #'id1 sig-of-name-stx))
       ;; This is the target define-values.
       (let ()
         (define rest-id-list (syntax->list #'(rest-ids ...)))
         ;; The rest-ids are: tmp1...tmpN proc-name1 proc-name2 ...
         ;; proc-names start at index num-fields.
         (define tmp-ids (take rest-id-list num-fields))
         (define proc-name-ids (drop rest-id-list num-fields))
           (define-values (new-proc-ids fo-defs)
            (if first-order?
                (make-first-order-wrappers proc-name-ids num-fields call-site-stx)
                (values proc-name-ids '())))
            ;; Collect proc-name symbols for the procedure signatures.
            ;; proc-name-ids order: (make-X X? X-f1 ... X-fN [set-X-f1! ...])
            (define proc-name-syms
              (map syntax-e proc-name-ids))
              ;; Capture phase-0 bindings for use in the template.
              (define wrap-procs-id (quote-syntax wrap-struct-procs))
              (define no-arb-id (quote-syntax no-arbitrary-sig))
              ;; Wrap each field-sig expression in (signature ...) so that
              ;; signature-only forms like ListOf, mixed, one-of, etc.
              ;; are handled by parse-signature rather than being evaluated raw.
              (define sig-macro-id (datum->syntax call-site-stx 'signature))
              (define wrapped-sig-exprs
                (map (lambda (s) #`(#,sig-macro-id #,s))
                     (syntax->list sig-exprs)))
              ;; For the name-of-val call (e.g. PersonOf), wrap each sig with
              ;; no-arbitrary-sig to block the eager arbitrary-promise forcing
              ;; chain that fails on forward-referenced / recursive types.
              (define no-arb-sig-exprs
                (map (lambda (s) #`(#,no-arb-id #,s))
                     wrapped-sig-exprs))
              (with-syntax ([(sig-expr ...) wrapped-sig-exprs]
                           [(no-arb-sig-expr ...) no-arb-sig-exprs]
                           [(tmp-id ...) tmp-ids]
                           [(new-proc-id ...) new-proc-ids]
                           [num-fields-val num-fields]
                           [(proc-name-sym-val ...) proc-name-syms]
                           [wrap-procs wrap-procs-id])
               (define rewritten-dv
                 (datum->syntax
                  expanded
                  #`(define-values (id0 id1 tmp-id ... new-proc-id ...)
                      (call-with-values
                       (lambda () body)
                       (lambda (name-val name-of-val . rest-vals)
                         ;; Compute the struct type signature: (NameOf Sig1 Sig2 ...)
                         ;; Use no-arbitrary-sig wrappers to prevent the eager
                         ;; arbitrary-promise forcing chain in PersonOf from
                         ;; reaching undefined forward-referenced signatures.
                         (let ([struct-sig (name-of-val no-arb-sig-expr ...)])
                           (apply values
                                  struct-sig
                                  name-of-val
                                  ;; Wrap constructor, predicate, and selectors
                                  ;; with procedure signatures.
                                  ;; Use the real sigs (with arbitrary) here.
                                  (wrap-procs '(proc-name-sym-val ...)
                                              (list sig-expr ...)
                                              struct-sig
                                              num-fields-val
                                              rest-vals))))))
                  expanded
                  expanded))
           (if first-order?
               ;; Wrap with begin: first-order define-syntax forms, then the define-values
               (datum->syntax expanded
                              #`(begin #,@fo-defs #,rewritten-dv)
                              expanded
                              expanded)
               rewritten-dv)))]
      [other expanded]))

  ;; Core logic for typed struct definition.
  ;; Called by both define-struct/typed and define-struct (typed branch).
  ;; call-site-stx must carry the student's lexical context for
  ;; bsl-context? detection and for scoping the emitted bindings.
  ;;
  ;; In ASL, we use advanced-define-struct (which generates setters and
  ;; uses make-combined-signature for the parametric signature).
  ;; In all other languages, we use intermediate-define-struct.
  ;; The expansion surgery handles both cases: the extra setter names
  ;; on the define-values LHS are simply passed through (ASL never
  ;; triggers first-order wrapping).
  (define (expand-typed-struct call-site-stx name-stx field-names-stx field-sigs-stx)
    (let* ([sig-name (make-signature-name name-stx)]
           [sig-of-name (make-parametric-signature-name name-stx)]
           [num-fields (length (syntax->list field-names-stx))]
           [first-order? (bsl-context? call-site-stx)]
           ;; Pick the right native define-struct variant:
           ;; ASL gets advanced-define-struct (setters, combined-signature),
           ;; everything else gets intermediate-define-struct.
           [native-ds (if (asl-context? call-site-stx)
                          #'advanced-define-struct
                          #'intermediate-define-struct)]
           [plain-form (datum->syntax call-site-stx
                                      #`(#,native-ds #,name-stx #,field-names-stx)
                                      call-site-stx)]
           ;; local-expand to get the structured expansion
           [expanded (local-expand plain-form
                                   (syntax-local-context)
                                   (list #'begin
                                         #'define-values
                                         #'define-syntaxes))])
      ;; Rewrite the expansion to replace Name with (NameOf Sig1 Sig2)
      ;; and, when in BSL/BSL+, add first-order wrappers for struct functions.
      (rewrite-define-values expanded sig-name sig-of-name
                             field-sigs-stx num-fields first-order?
                             call-site-stx)))

  ) ;; end begin-for-syntax



;; # Configuration: Signature violation deduplication


;; ## Parameters

;; max-signature-violations controls how many violations per bucket
;; are shown before further ones are dropped.
;;
;;   (max-signature-violations 1)   ; default: first violation only
;;   (max-signature-violations 3)   ; up to 3
;;   (max-signature-violations #f)  ; unlimited (original behaviour)
;;
;; signature-violation-dedup selects how violations are sorted into buckets:
;;
;;   'type-name  – one bucket per named type (most aggressive)
;;   'signature  – one bucket per (type-name, signature object)   [default]
;;   'object     – one bucket per (type-name, bad value identity)
;;
;; For example, with cap = 1 and mode = 'signature, each distinct
;; signature object (e.g. each `: …` annotation and each define-type)
;; independently gets 1 violation shown.

(define max-signature-violations (make-parameter 1))
(define signature-violation-dedup (make-parameter 'signature))


;; ## Enhanced signature violation messages & deduplication

;; Override the signature-violation-proc to:
;;
;; 1. Include the type name in the error message, and use format "expected ..., but got ...".
;;    Example: "expected a PossiblyString, but got 3"
;;    instead of the default: "got 3"
;;
;; 2. Suppress cascading/duplicate violations.
;;    In teaching languages the violation handler logs and returns
;;    (execution continues), so recursive functions re-check the same
;;    bad data at every call boundary, producing a flood of redundant
;;    messages.  The dedup counter, gated by max-signature-violations,
;;    limits how many violations per bucket are shown.
;;
;;    Bucket selection is controlled by signature-violation-dedup:
;;      'type-name  → key = name             (most aggressive)
;;      'signature  → key = (name . eq-id)   of the sig object
;;      'object     → key = (name . eq-id)   of the bad value
;;
;; The hash-set! that records a violation runs AFTER the delegate call,
;; so when the delegate raises an exception (rackunit / default context)
;; the hash is never updated and dedup is effectively inactive — all
;; existing tests pass unchanged.
;;
;; 3. Fix the violation source location in DrRacket.
;;    DrRacket's errortrace annotates every expression with continuation
;;    marks, which it exposes through the parameter
;;    errortrace-continuation-mark-set->context.  When our handler calls
;;    report-signature-violation!, its continuation-marks-srcloc picks up
;;    a sludges frame instead of the user's code.  After the delegate
;;    returns (teaching language context only), we replace the srcloc on
;;    the most-recently added signature-violation with one computed by our
;;    own continuation-marks-srcloc that filters out sludges frames.

;; Source path of this very module, used to recognize sludges frames even
;; when this file is not installed as part of the sludges collection (for
;; example, as a standalone teachpack).
(define this-module-source
  (variable-reference->module-source (#%variable-reference)))

;; Like test-engine/srcloc's continuation-marks-srcloc, but also
;; filters out frames originating from the sludges implementation.
(define (user-srcloc marks)
  (let ([cms ((or (errortrace-continuation-mark-set->context)
                  continuation-mark-set->context)
              marks)])
    (and (list? cms)
         (findf
          (lambda (mark)
            (and (srcloc? mark)
                 (let ([ppath (srcloc-source mark)])
                   (or (and (path? ppath)
                            (not (equal? ppath this-module-source))
                            (not (let ([rel (path->collects-relative ppath)])
                                   (and (pair? rel)
                                        (eq? 'collects (car rel))
                                        (member (cadr rel)
                                                '(#"lang"
                                                  #"deinprogramm"
                                                  #"sludges"
                                                  #"installed-teachpacks"))))))
                       (symbol? ppath)))))
          cms))))

(let ([original-proc (signature-violation-proc)]
      ;; key → count
      [seen (make-hash)])
  (signature-violation-proc
   (lambda (obj sig message blame-srcloc)
     (let ([enhanced-message
             (if (and (not message) (signature-name sig))
                 (let* ([name (signature-name sig)]
                        [name-str (if (symbol? name) (symbol->string name)
                                      (format "~a" name))]
                        [article (if (and (> (string-length name-str) 0)
                                          (memv (char-downcase (string-ref name-str 0))
                                                '(#\a #\e #\i #\o #\u)))
                                     "an" "a")])
                   (format "expected ~a ~a, but got ~e" article name obj))
                 message)]
           ;; Capture the correct srcloc now, before calling original-proc.
           [correct-srcloc (user-srcloc (current-continuation-marks))]
           [cap (max-signature-violations)]
           [name (signature-name sig)]
           [mode (signature-violation-dedup)])
       (let ([key
              (and cap name mode
                   (cond
                     [(eq? mode 'type-name)  name]
                     [(eq? mode 'signature)  (cons name (eq-hash-code sig))]
                     [(eq? mode 'object)     (cons name (eq-hash-code obj))]
                     [else                   #f]))])
         (cond
           ;; Cap active, bucket identified, already at cap → suppress
           [(and key (>= (hash-ref seen key 0) cap))
            (void)]
           ;; Otherwise report and (if delegate returns) bump the counter
           [else
            (original-proc obj sig enhanced-message blame-srcloc)
            ;; Only reached when original-proc returns (teaching language).
            ;; In exception context (rackunit) the line below is never
            ;; executed, so the hash stays empty and dedup stays inactive.
            ;;
            ;; Fix up the srcloc: report-signature-violation! used
            ;; continuation-marks-srcloc which picked up a sludges frame.
            ;; Replace it with the correct user-code srcloc.
            (when correct-srcloc
              (let* ([to  (te:current-test-object)]
                     [vs  (te:test-object-signature-violations to)])
                (when (pair? vs)
                  (let ([v (car vs)])
                    (te:set-test-object-signature-violations!
                     to
                     (cons (te:signature-violation
                            (te:signature-violation-obj v)
                            (te:signature-violation-signature v)
                            (te:signature-violation-message v)
                            correct-srcloc
                            (te:signature-violation-blame-srcloc v))
                           (cdr vs)))))))
            (when key
              (hash-set! seen key (add1 (hash-ref seen key 0))))]))))))



;; # Module exports

(provide one-of
         define-type
         define-type-constructor
         define-header
         define-template
         max-signature-violations
         signature-violation-dedup
         Image
         MouseEvent
         KeyEvent
         List
         Maybe
         Cons
         Add1
         Vector
         VectorOf
         Void
          Posn
          PosnOf
          define-struct/typed
          define-struct
          integer-from-to
          integer-from
          integer-to
          number-from-to
          number-from<-to
          number-from-<to
          number-from<-<to
          number-from
          number-from<
          number-to
          number-<to
          ;; Referenced by the expansion of define-type-constructor and
          ;; define-type, so they have to cross the module boundary; they
          ;; are not part of the user-facing interface.
          make-lifted-signature
          check-type-constructor!)
