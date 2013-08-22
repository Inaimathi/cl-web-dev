;;;; package.lisp
(defpackage #:cl-web-dev
  (:use #:cl #:parenscript)
  (:import-from #:hunchentoot #:define-easy-handler #:stop)
  (:import-from #:cl-who #:with-html-output-to-string #:with-html-output #:htm #:fmt #:str)
  (:export
   ;; general
   #:with-gensyms #:aif #:awhen #:with-overwrite #:to-file
   
   ;; hunchentoot interaction
   #:define-handler #:easy-start #:stop

   ;; cl-who interaction
   #:html-str #:html #:scripts #:styles #:htm #:fmt #:str

   ;; parenscript interaction (the cl-web-dev includer will still need parenscript)
   #:obj->string #:string->obj #:fn
   #:$ #:$int #:$float #:$click #:$right-click
   #:doc-ready #:$map #:$grep #:$highlight 
   #:$post #:$droppable #:$draggable))
