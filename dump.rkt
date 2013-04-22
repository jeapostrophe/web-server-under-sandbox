#lang racket/base
(require plot
         racket/file
         racket/list
         racket/format
         racket/string
         racket/match
         racket/cmdline
         racket/runtime-path)

(define (parse-dump p)
  (define type->k (make-hash))
  (define type->mem (make-hash))
  (define CMU #f)
  (define PMU #f)
  (define APS #f)
  (define RPS #f)
  (define MCs #f)
  (define MiCs #f)
  (define FINS #f)
  (define TE #f)
  (define IB #f)
  (let loop ()
    (match (read-line p)
      ;; Meh
      ["uncaught exception: #<exn:dispatcher>"
       (loop)]
      ;; Real
      [(? eof-object? e)
       e]
      ["Begin Dump"
       (loop)]
      ["Begin Racket3m"
       (loop)]
      [(regexp #rx"^ *(.+): +([0-9]+) +([0-9]+)$"
               (list _ type
                     (app string->number k)
                     (app string->number mem)))
       (hash-set! type->k type k)
       (hash-set! type->mem type mem)
       (loop)]
      ["End Racket3m"
       (loop)]
      ;; XXX
      [(regexp #rx"^Generation" (list _))
       (loop)]
      [""
       (loop)]
      [(regexp #rx"Current memory use: ([0-9]+)$"
               (list _ (app string->number cmu)))
       (set! CMU cmu)
       (loop)]
      [(regexp #rx"Peak memory use after a collection: ([0-9]+)$"
               (list _ (app string->number cmu)))
       (set! PMU cmu)
       (loop)]
      [(regexp #rx"Allocated \\(\\+reserved\\) page sizes: ([0-9]+) \\(\\+([0-9]+)\\)$"
               (list _
                     (app string->number aps)
                     (app string->number rps)))
       (set! APS aps)
       (set! RPS rps)
       (loop)]
      [(regexp #rx"# of major collections: ([0-9]+)$"
               (list _ (app string->number cmu)))
       (set! MCs cmu)
       (loop)]
      [(regexp #rx"# of minor collections: ([0-9]+)$"
               (list _ (app string->number cmu)))
       (set! MiCs cmu)
       (loop)]
      [(regexp #rx"# of installed finalizers: ([0-9]+)$"
               (list _ (app string->number cmu)))
       (set! FINS cmu)
       (loop)]
      [(regexp #rx"# of traced ephemerons: ([0-9]+)$"
               (list _ (app string->number cmu)))
       (set! TE cmu)
       (loop)]
      [(regexp #rx"# of immobile boxes: ([0-9]+)$"
               (list _ (app string->number cmu)))
       (set! IB cmu)
       (loop)]
      ["End Dump"
       (vector type->k type->mem
               CMU PMU
               APS RPS
               MCs MiCs
               FINS TE IB)])))

(define (analyze-dump dp out-d)
  (define dumps
    (with-input-from-file dp
      (λ ()
        (for/list ([d (in-port parse-dump)])
          d))))

  (define object->extractor (make-hash))
  (for* ([d (in-list dumps)]
         [o (in-hash-keys (vector-ref d 0))])
    (hash-set! object->extractor
               o
               (λ (d) (hash-ref (vector-ref d 0) o 0))))
  (hash-set! object->extractor
             "installed finalizers"
             (λ (d) (vector-ref d 8)))
  (hash-set! object->extractor
             "traced emphemerons"
             (λ (d) (vector-ref d 9)))
  (hash-set! object->extractor
             "immobile boxes"
             (λ (d) (vector-ref d 10)))

  (define obj-d (build-path out-d "objs"))
  (unless (directory-exists? obj-d)
    (make-directory obj-d))
  (for/list ([(o of) (in-hash object->extractor)])
    (plot-file
     #:title o
     #:y-min -1
     (points (for/list ([i (in-naturals)] [d (in-list dumps)])
               (vector i (of d))))
     (build-path obj-d (format "~a.png" o))))

  (plot-file
   (list (list (points #:label "CMU"
                       (for/list ([i (in-naturals)] [d (in-list dumps)])
                         (vector i (vector-ref d 2))))
               (points #:label "PMU"
                       (for/list ([i (in-naturals)] [d (in-list dumps)])
                         (vector i (vector-ref d 3))))))
   (build-path out-d "mem.png"))

  (plot-file
   (list (list (points #:label "APS"
                       (for/list ([i (in-naturals)] [d (in-list dumps)])
                         (vector i (vector-ref d 4))))
               (points #:label "RPS"
                       (for/list ([i (in-naturals)] [d (in-list dumps)])
                         (vector i (vector-ref d 5))))))
   (build-path out-d "pages.png"))

  (plot-file
   (list (list (points #:label "Major"
                       (for/list ([i (in-naturals)] [d (in-list dumps)])
                         (vector i (vector-ref d 6))))
               (points #:label "Minor"
                       (for/list ([i (in-naturals)] [d (in-list dumps)])
                         (vector i (vector-ref d 7))))))
   (build-path out-d "collects.png")))

(module+ main
  (define-runtime-path dump-p "dump")
  (define-runtime-path dump.png-p "dump-pngs")
  (unless (directory-exists? dump.png-p)
    (make-directory dump.png-p))

  (void (analyze-dump dump-p dump.png-p)))
