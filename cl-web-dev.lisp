;;;; cl-web-dev.lisp
(in-package #:cl-web-dev)

;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; General utility
(defmacro with-overwrite (stream file-name &body body)
  (with-gensyms (fname)
    `(let ((,fname ,file-name))
       (ensure-directories-exist ,fname)
       (with-open-file (,stream ,fname :direction :output :if-exists :supersede :if-does-not-exist :create)
	 ,@body))))

(defmacro with-append (stream file-name &body body)
  (with-gensyms (fname)
    `(let ((,fname ,file-name))
       (ensure-directories-exist ,fname)
       (with-open-file (,stream ,fname :direction :output :if-exists :append :if-does-not-exist :create)
	 ,@body))))

(defmethod to-file ((fname string) dat) 
  (to-file (pathname fname) dat))

(defmethod to-file ((fname pathname) (dat string))
  (with-overwrite stream fname
    (format stream dat)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Hunchentoot-related
(defun easy-start (port &optional static-dir)
  (let ((server (hunchentoot:start (make-instance 'hunchentoot:easy-acceptor :port port))))
    (when static-dir
      (push (hunchentoot:create-folder-dispatcher-and-handler "/static/" static-dir)
	    hunchentoot:*dispatch-table*))
    server))

(defmacro define-handler (name args &body body)
  `(define-easy-handler (,name :uri ,(string-downcase (concatenate 'string "/" (symbol-name name)))) ,args
     ,@body))

;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; HTML-related 
(defmacro html-prologue (&body body)
  "Shortcut for with-html-output-to-string."
  `(with-html-output-to-string (*standard-output* nil :prologue t)
     ,@body))

(defmacro html-str (&body body)
  "Shortcut for with-html-output-to-string."
  `(with-html-output-to-string (*standard-output*)
     ,@body))

(defmacro html (&body body)
  "Shortcut for with-html-output."
  `(with-html-output (*standard-output*)
     ,@body))

(defun scripts (&rest files)
  "Shortcut for declaring js includes on the front-end."
  (html (dolist (f files)
	  (htm (:script :type "text/javascript"
			:src (concatenate 'string "/static/js/" f))))))

(defun styles (&rest files)
  "Shortcut for declaring CSS includes on the front-end."
  (html (dolist (f files)
	  (htm (:link :rel "stylesheet" :type "text/css"
		      :href (concatenate 'string "/static/css/" f))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Parenscript-related
;;;;;;;;;;;;;;;;;;;; JS basic
(defparameter *debugging?* t)

(defpsmacro log (&body body)
  (when *debugging?*
    `(chain console (log ,@body))))

(defpsmacro obj->string (thing)
  `(chain -j-s-o-n (stringify ,thing)))

(defpsmacro string->obj (thing)
  `(chain j-query (parse-j-s-o-n ,thing)))

(defpsmacro map-markup (lst &body elem-markup)
  `(chain (loop for elem in ,lst
	     collect (who-ps-html ,@elem-markup))
	  (join "")))

(defpsmacro fn (&body body) `(lambda () ,@body))

(defpsmacro $aif (test-form then-form &optional else-form)
  `(let ((it ,test-form))
     (if it ,then-form ,else-form)))

(defpsmacro $awhen (test-form &body when-true)
  `($aif ,test-form (progn ,@when-true)))

;;;;;;;;;;;;;;;;;;;; jQuery Basics
(defpsmacro $ (selector &body chains)
  `(chain (j-query ,selector) ,@chains))

(defpsmacro $exists? (selector)
    `(> (@ ($ ,selector) length) 0))

(defpsmacro $val (selector)
  (with-ps-gensyms (sel type elem)
    `(let* ((,sel ,selector)
	    (,elem ($ ,sel))
	    (,type (chain ,elem (get 0) tag-name)))
       (case ,type
	 ("INPUT" (chain ,elem (val)))
	 ("TEXTAREA" (chain ,elem (val)))
	 (t (chain ,elem (text)))))))

(defpsmacro $int (selector &optional (start 0))
  `(parse-int (chain ($val ,selector) (substring ,start))))

(defpsmacro $float (selector &optional (start 0))
  `(parse-int (chain ($val ,selector) (substring ,start))))

(defpsmacro doc-ready (&body body) 
  `($ document (ready (fn ,@body))))

(defpsmacro $map (list &body body)
  (with-ps-gensyms (lst)
    `(let ((,lst ,list)) 
       (when ,lst (chain j-query (map ,lst (lambda (elem i) ,@body)))))))

(defpsmacro $grep (lst &body body)
  `(chain j-query (grep ,lst (lambda (elem i) ,@body))))

(defpsmacro $get (uri arg-plist &body body)
  `(chain j-query 
	  (get ,uri (create ,@arg-plist)
		(lambda (data status jqXHR)
		  (let ((res (string->obj (@ jqXHR response-text))))
		    ,@body)))))

(defpsmacro $post (uri arg-plist &body body)
  `(chain j-query 
	  (post ,uri (create ,@arg-plist)
		(lambda (data status jqXHR)
		  (let ((res (string->obj (@ jqXHR response-text))))
		    ,@body)))))

(defpsmacro $upload (target-form uri &rest success)
  (with-ps-gensyms (form-data)
    `(let ((,form-data (new (-form-data (aref ($ ,target-form) 0)))))
       (chain j-query
	      (ajax (create :url ,uri
			    :type "POST"
			    :success (lambda (data status jqXHR)
				       (let ((res (string->obj (@ jqXHR response-text))))
					 ,@success))
			    :error (lambda (jqXHR status error-thrown)
				     (log "UPLOAD ERRORED" jqXHR status error-thrown))
			    :data ,form-data
			    :cache false
			    "contentType" false
			    "processData" false))))))

(defpsmacro $highlight (target)
  `($ ,target (stop t t) (effect :highlight nil 500)))

(defparameter mod-keys 
  `((shift? (@ event shift-key))
    (alt? (@ event alt-key))
    (ctrl? (@ event ctrl-key))
    (meta? (@ event meta-key))))

(defparameter key-codes
  `((<ret> 13) (<esc> 27) (<space> 32) 
    (<up> 38) (<down> 40) (<left> 37) (<right> 39)))

(defpsmacro $droppable (target (&key overlapping) &rest class/action-list)
  `($ ,target
      (droppable 
       (create 
	:drop (lambda (event ui)
		(let ((dropped (@ ui helper context))
		      ,@mod-keys)
		  (cond ,@(loop for (class . action) in class/action-list
			     collect `(($ dropped (has-class ,class)) ,@action)))
		  ($ ,overlapping (droppable "enable"))))
	,@(when overlapping
		`(:over (fn ($ ,overlapping (droppable "disable")))
		  :out (fn ($ ,overlapping (droppable "enable")))))))))

(defpsmacro $draggable (target (&key revert handle cancel) &body body)
  `($ ,target (draggable (create :stop (lambda (event ui) 
					 (let (,@mod-keys)
					   ,@body))
				 ,@(when revert `(:revert ,revert))
				 ,@(when handle `(:handle ,handle))
				 ,@(when cancel `(:cancel ,cancel))))))

(defpsmacro $keydown (target &rest key/body-pairs)
  `($ ,target
      (keypress
       (lambda (event)
	 (let (,@mod-keys
	       ,@key-codes
	       (key-code (or (@ event key-code) (@ event which))))
	   (cond ,@(loop for (key body) on key/body-pairs by #'cddr
		      collect `((= key-code ,(if (stringp key) `(chain ,key (char-code-at 0)) key)) ,body))))))))

(defpsmacro $on (context-selector &rest event/selector/behavior-list)
  `($ ,context-selector
      ,@(loop for (ev sel . behav) in event/selector/behavior-list
	   collect 
	     `(on ,ev ,sel (lambda (event) 
			     ,@(if (eq ev :keydown)
				   `((let (,@mod-keys ,@key-codes
					   (key-code (or (@ event key-code) (@ event which))))
				       (cond ,@(loop for (key body) on behav by #'cddr
						  collect `((= key-code ,(if (stringp key) `(chain ,key (char-code-at 0)) key)) ,body)))))
				   behav))))))

(defpsmacro $button (selector (icon-name &key text? class) &body on-click)
  `($ ,selector
      (button (create :icons (create :primary ,(format nil "ui-icon-~(~a~)" icon-name)) :text ,(when text? t)))
      (click (lambda (event) ,@on-click))
      ,@(when class `((add-class ,class)))))

(defpsmacro $click (&rest target/body-list)
  `(progn ,@(loop for (target body) on target/body-list by #'cddr
	       collect `($ ,target (click (lambda (event) ,body))))))

(defpsmacro $right-click (target &rest body)
  (with-gensyms (fn)
    `(let ((,fn (lambda (event) ,@body)))
       ($ ,target
	  (bind :contextmenu
		(lambda (event)
		  (,fn event)
		  (chain event (prevent-default))))
	  (bind :oncontextmenu
		(lambda (event)
		  (,fn event)
		  (setf (@ window event return-value) false)))))))

(defpsmacro $append (target &rest html)
  `($ ,target (append (who-ps-html ,@html))))

(defpsmacro $prepend (target &rest html)
  `($ ,target (prepend (who-ps-html ,@html))))

(defpsmacro $replace (target &rest html)
  `($ ,target (replace-with (who-ps-html ,@html))))

(defpsmacro event-source (uri &body name/body-list)
  (with-gensyms (stream handlers ev)
    `(let ((,stream (new (-event-source ,uri)))
	   (,handlers (create ,@(loop for (name . fn-body) in name/body-list
				  collect `,name collect `(lambda (ev) ,@fn-body)))))
       (setf (@ ,stream onopen) (lambda (e) (log "Stream OPENED!"))
	     (@ ,stream onerror) (lambda (e) (log "Stream ERRORED!" e))
	     (@ ,stream onmessage)
	     (lambda (e) 
	       (let ((,ev (string->obj (@ e data))))
		 ((@ ,handlers (@ ,ev type)) ,ev))))
       ,stream)))
