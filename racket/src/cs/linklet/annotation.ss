(define (correlated->annotation v)
  (let-values ([(e stripped-e) (correlated->annotation* v)])
    e))

(define (correlated->annotation* v)
  (cond
   [(pair? v) (let-values ([(a stripped-a) (correlated->annotation* (car v))]
                           [(d stripped-d) (correlated->annotation* (cdr v))])
                (if (and (eq? a (car v))
                         (eq? d (cdr v)))
                    (values v v)
                    (values (cons a d)
                            (cons stripped-a stripped-d))))]
   [(correlated? v) (let-values ([(e stripped-e) (correlated->annotation* (correlated-e v))])
                      (let ([name (correlated-property v 'inferred-name)])
                        (define (add-name e)
                          (if (and name (not (void? name)))
                              `(|#%name| ,name ,e)
                              e))
                        (values (add-name (transfer-srcloc v e stripped-e))
                                (add-name stripped-e))))]
   ;; correlated will be nested only in pairs with current expander
   [else (values v v)]))

(define (transfer-srcloc v e stripped-e)
  (let ([src (correlated-source v)]
        [pos (correlated-position v)]
        [line (correlated-line v)]
        [column (correlated-column v)]
        [span (correlated-span v)])
    (if (and pos span (or (path? src) (string? src)))
        (let ([pos (sub1 pos)]) ; Racket positions are 1-based; host Scheme positions are 0-based
          (make-annotation e
                           (if (and line column)
                               ;; Racket columns are 0-based; host-Scheme columns are 1-based
                               (make-source-object (source->sfd src) pos (+ pos span) line (add1 column))
                               (make-source-object (source->sfd src) pos (+ pos span)))
                           stripped-e))
        e)))

(define sfd-cache (make-weak-hash))

(define (source->sfd src)
  (or (hash-ref sfd-cache src #f)
      (let ([str (if (path? src)
                     (path->string src)
                     src)])
        ;; We'll use a file-position object in source objects, so
        ;; the sfd checksum doesn't matter
        (let ([sfd (source-file-descriptor str 0)])
          (hash-set! sfd-cache src sfd)
          sfd))))

;; --------------------------------------------------

(define (strip-nested-annotations s)
  (cond
   [(annotation? s) (annotation-stripped s)]
   [(pair? s)
    (let ([a (strip-nested-annotations (car s))]
          [d (strip-nested-annotations (cdr s))])
      (if (and (eq? a (car s)) (eq? d (cdr s)))
          s
          (cons a d)))]
   [else s]))
