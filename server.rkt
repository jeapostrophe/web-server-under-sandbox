#lang racket/base

(require web-server/servlet-dispatch
         (prefix-in fsmap: web-server/dispatchers/filesystem-map)
         (prefix-in sequencer: web-server/dispatchers/dispatch-sequencer)
         (prefix-in files: web-server/dispatchers/dispatch-files)
         (prefix-in lift: web-server/dispatchers/dispatch-lift)
         web-server/dispatchers/dispatch
         net/url
         web-server/http
         web-server/private/mime-types
         web-server/http/xexpr
         racket/runtime-path
         (for-syntax racket/base))

(provide start-server)

(define-runtime-path htdocs (build-path "htdocs"))

(define (start req)
  (unless (regexp-match #rx"compile" (url->string (request-uri req)))
    (next-dispatcher))
  #;(error 'test "trying to trace gc error")
  (response/xexpr '(html (head) (body "Ok"))))

(define (start-server #:port [port 8000]
                      #:listen-ip [listen-ip "127.0.0.1"])
  (thread (lambda ()
            (printf "starting web server on port ~s\n" port)

            (define (dispatcher sema)
              (sequencer:make
               (lift:make start)
               (files:make
                #:url->path (fsmap:make-url->path htdocs)
                #:path->mime-type
                (make-path->mime-type "/etc/mime.types")
                #:indices (list "index.html" "index.htm"))))

            (serve/launch/wait
             dispatcher
             #:listen-ip listen-ip
             #:launch-path #f
             #:port port))))

(module+ main
  (define current-port (make-parameter 8080))
  (require racket/cmdline)
  (void (command-line
         #:once-each
         [("-p" "--port") p "Port (default 8000)"
          (current-port (string->number p))]))
  (sync (start-server #:port (current-port))))
