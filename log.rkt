#lang racket/base
(require plot
         racket/file
         racket/list
         racket/format
         racket/string
         racket/match
         racket/cmdline
         racket/runtime-path)

(define (display-log p rp)
  (define ds
    (for/list ([l (file->lines p)])
      (match-define (cons dir more) (string-split l))
      (cons dir (map string->number more))))
  (define (k-points ds k)
    (for/list ([d (in-list ds)] [i (in-naturals)])
      (vector i (list-ref d k))))

  (parameterize ([plot-y-ticks 
                  (ticks (linear-ticks-layout)
                         (λ (s e m)
                           (map (λ (pt)
                                  (->mbs (pre-tick-value pt)))
                                m)))])
    (plot-file
     #:title "Memory under pressre"
     #:x-label "Requests"
     #:y-label "MBs"
     (points (k-points ds 4))
     rp))

  (define cycles
    (reverse
     (for/fold ([cs (list empty)]) ([d (in-list ds)])
       (match (first d)
         ["U" (list* (list* d (first cs)) (rest cs))]
         ["D" (list* (list d) (list* (reverse (first cs)) (rest cs)))]))))

  (for/fold ([last 0])
      ([c (in-list cycles)]
       [i (in-naturals)])
    (define start (list-ref (first c) 4))
    (define end
      ;;(list-ref (last c) 4)
      (apply max (map (λ (l) (list-ref l 4)) c)))
    (displayln
     (~a "Cycle "
         (~a #:align 'right #:min-width 2 i)
         " "
         (~a #:align 'right #:min-width 3 (length c))
         " reqs "

         "Start "
         (~a #:align 'right #:min-width 6
             (->mbs start))
         "MBs "

         "End "
         (~a #:align 'right #:min-width 6
             (->mbs end))
         "MBs "

         "Alloc "
         (~a #:align 'right #:min-width 5
             (->mbs (- end start)))
         "MBs "

         "Leak "
         (~a #:align 'right #:min-width 5
             (->mbs (- start last)))
         "MBs "))
    start))

(define (->mbs bs)
  (real->decimal-string (/ (/ bs 1024) 1024)))

(module+ main
  (define-runtime-path log-p "log")
  (define-runtime-path log.png-p "log.png")

  (display-log log-p log.png-p))
