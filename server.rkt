#lang racket/base

(require web-server/servlet-env
         web-server/servlet
         web-server/http/xexpr
         racket/runtime-path
         (for-syntax racket/base))

(provide start-server)

(define-runtime-path htdocs (build-path "htdocs"))

(define (start req)
  (error 'test "trying to trace gc error")
  #;(response/xexpr '(html (head) (body "Ok"))))

(define (start-server #:port [port 8000]
                      #:listen-ip [listen-ip "127.0.0.1"])
    (thread (lambda ()
              (printf "starting web server on port ~s\n" port)
              (serve/servlet start 
                             #:listen-ip listen-ip
                             #:servlet-path "/compile"
                             #:extra-files-paths (list htdocs)
                             #:launch-browser? #f
                             #:port port))))

(module+ main
  (define current-port (make-parameter 8080))
  (require racket/cmdline)
  (void (command-line
         #:once-each 
         [("-p" "--port") p "Port (default 8000)" 
          (current-port (string->number p))]))
  (sync (start-server #:port (current-port))))
  
