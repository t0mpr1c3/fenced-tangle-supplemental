#lang racket

;; https://doi.org/10.1145/3592449

(provide cmd/c
         (contract-out
          [parse-command (-> syntax? string? cmd/c)]))

(require racket/syntax
         syntax/parse
         threading)
(require "fnitout-contracts.rkt")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; contract for command

(define cmd/c
  (or/c tuck/c
        knit/c
        split/c
        miss/c
        in/c
        out/c
        drop/c
        xfer/c
        rack/c
        nop/c
        void?))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; parse command

(define (parse-command command-stx comment)
  (syntax-parse command-stx
    [(_ {~literal TUCK} dir-stx needle-stx length-stx yarn-stx)
     (Tuck (parse-direction #'dir-stx)
           (parse-needle #'needle-stx)
           (parse-length #'length-stx)
           (parse-yarn #'yarn-stx)
           comment
           null)]
    [(_ {~literal KNIT} dir-stx needle-stx length-stx yarn-stxs ...)
     (Knit (parse-direction #'dir-stx)
           (parse-needle #'needle-stx)
           (parse-length #'length-stx)
           (parse-yarns #'(yarn-stxs ...))
           comment
           null)]
    [(_ {~literal SPLIT} dir-stx src-needle-stx dst-needle-stx length-stx yarn-stxs ...)
     (Split (parse-direction #'dir-stx)
            (parse-needle #'src-needle-stx)
            (parse-needle #'dst-needle-stx)
            (parse-length #'length-stx)
            (parse-yarns #'(yarn-stxs ...))
            comment
           null)]
    [(_ {~literal MISS} dir-stx needle-stx carrier-stx)
     (Miss (parse-direction #'dir-stx)
           (parse-needle #'needle-stx)
           (parse-carrier #'carrier-stx)
           comment
           null)]
    [(_ {~literal IN} dir-stx needle-stx carrier-stx)
     (In (parse-direction #'dir-stx)
         (parse-needle #'needle-stx)
         (parse-carrier #'carrier-stx)
         comment
           null)]
    [(_ {~literal OUT} dir-stx needle-stx carrier-stx)
     (Out (parse-direction #'dir-stx)
          (parse-needle #'needle-stx)
          (parse-carrier #'carrier-stx)
          comment
           null)]
    [(_ {~literal DROP} needle-stx)
     (Drop (parse-needle #'needle-stx)
           comment
           null)]
    [(_ {~literal XFER} src-needle-stx dst-needle-stx)
     (Xfer (parse-needle #'src-needle-stx)
           (parse-needle #'dst-needle-stx)
           comment
           null)]
    [(_ {~literal RACK} racking-stx)
     (Rack (parse-racking #'racking-stx)
           comment
           null)]
    [(_ {~literal NOP})
     (Nop comment
           null)]
    [({~literal comment} comment-stx)
     (Nop (syntax->datum #'comment-stx)
           null)]))

;; sort yarns by carrier
(define (parse-yarns yarns-stx)
  (syntax-parse yarns-stx
    [(yarn-stxs ...)
     (~> #'(yarn-stxs ...)
         syntax->list
         (map parse-yarn _)
         ;(filter-new (compose Carrier-val Yarn-carrier))) ;; keep only first of duplicate carriers
         (assert-new (compose Carrier-val Yarn-carrier)) ;; throw error if duplicate carriers
         (sort < #:key (compose Carrier-val Yarn-carrier)))]))

;; flag duplicates as false in list of Booleans
(define (map-duplicate? xs func)
  (let loop ([tail xs]
             [seen (set)]
             [keep null])
    (if (null? tail)
        (reverse keep)
        (let ([k (func (car tail))])
          (if (set-member? seen k)
              ;; reject
              (loop (cdr tail)
                    set
                    (cons #f keep))
              ;; keep
              (loop (cdr tail)
                    (apply set (cons k (set->list seen)))
                    (cons #t keep)))))))

(define (keep xs ks)
  (filter-not false?
              (for/list ([x (in-list xs)]
                         [k (in-list ks)])
                (if k x #f))))

(define (filter-new xs func)
  (keep xs (map-duplicate? xs func)))

(define (assert-new xs func)
  (unless (for/and ([i (in-list (map-duplicate? xs func))]) i)
    (error 'fnitout "duplicate carrier in yarns"))
  xs)

;; end
