# cl-web-dev
###### Because I don't want to write this shit every time

#### What this is

A collection of functions and macros I've found useful while doing web development in Common Lisp. These particular ones make enough sense to me that I always either define them up-front when starting a new system, or I wish I had them. There's some non-web related stuff that I've nevertheless found useful in enough related projects that they're in. *You* may not find them useful, in which case you should continue doing what you're doing.

#### What this isn't

- A framework. I guess you could call it a tool-kit, but that makes it sound heavier than it is.
- Platform Independent. It uses [cl-who](http://weitz.de/cl-who/), [hunchentoot](http://weitz.de/hunchentoot/) and [parenscript](http://common-lisp.net/project/parenscript/), and isn't built to support anything else.
- A way to avoid learning `cl-who`, `parenscript` or `hunchentoot`. It lets you use each of them a bit more easily, but that's all.

### Latest Changes

- Added `$upload` macro
- Added `$on` and `$button` macros
- Added `$append`, `$prepend` and `$replace` macros
- Changed `$keypress` to `$keydown`
- Added `map-markup`; a function to make it easier to generate markup with `who-ps-html`
- Added `$val`, a macro that returns the targets `.text()` or `.val()` depending on context
- Added `$exists?` because I got sick of having to remember the trick to get this behavior out of jQuery (You need to check the length of the return array when running a selector).
 
# Usage

You just need to `:use` the packages `:cl-web-dev` and `:parenscript` in whatever project you'd like. Load the others mentioned, but `:cl-web-dev` re-exports all the relevant symbols from `:cl-who` and `:hunchentoot`, so you don't need to worry about those. 

The "Hello World" is...

    (ql:quickload :cl-web-dev)
    (defpackage :your-package (:use :cl :cl-web-dev :parenscript))
    (in-package :your-package)
    
    (define-handler test ()
      (html-str
        (:html
          (:body
           (:h1 "Hello World!")
           (:p "From" (:code "cl-web-dev") "!")
           (:script (str (ps (alert "And also, parenscript"))))))))
    
    (defparameter server (easy-start 4242))

# Exported Symbols

## General purpose stuff

#### with-overwrite

Basic macro that provides a particular series of default values to `with-open-file`. In particular, it ensures that the specified directories exist, automatically creates a nonexistant file, and automatically over-writes an existing one.

Takes a `stream`, a `filename` and a `body`. Executes `body` with `stream` outputting to `filename`.

#### with-append

As `with-overwrite`, but if the specified file already exists, it appends instead of overwriting.

#### to-file

Minimal interface layer to `with-overwrite`. 

Takes a file-name and a string. Writes the string to the named file.

## Hunchentoot-related

There are really only four things I ever do with Hunchentoot. Define handlers, define a static directory, poke at `session` and start the server. Very occasionally, I also stop the server. `cl-web-dev` re-exports `stop`, `session-start`, `session-value`, `delete-session-value` and `remove-session`, and defines the following to help with the rest

#### easy-start

Takes a port number, and optionally, a pathname to a static directory. Starts a `hunchentoot:easy-acceptor` listening on the port number, and serves up the static directory if specified.

#### define-handler

A thin wrapper over `define-easy-handler`. It assigns the handlers' `uri` based on its name to simplify definition slightly.

## cl-who-related

#### html-str

A shortcut providing reasonable defaults (and a shorter name) for `with-html-output-to-string`.

#### html-prologue

As `html-str`, but for `(with-html-output-to-string (*standard-output* nil :prologue t) ...)`. This is the one you want to use at the top-level of your html generators because it generates a `!DOCTYPE` for you.

#### html

Same as `html-str`, but for `with-html-output`.

#### scripts

Takes a bunch of file names, and generates the `script` tags to serve them from your static directory.

#### styles

As `scripts`, but for stylesheets rather than javascript.

## parenscript

Mostly, these are tiny utility macros that provide a simple interface to [jQuery](http://jquery.com/) through `parenscript`. You're still expected to include `parenscript`, and serve up a `jquery.js` yourself. Maybe that could be made a bit simpler...

#### obj->string

Takes a JSON object and stringifies it.

#### string->obj

Takes a string and tries to parse it into a JSON object.

#### map-markup

Takes a list, and som element markup. Collects the results of applying the markup to each element of list. Automatically applies `join` to avoid commas in modern browsers.

#### fn

Shorthand for the anonymous function of zero arguments.

#### log

Shorthand for `(chain console (log ...))`. A related symbol is `*debugging?*`; if it's set to `nil`, a call to `log` will expand into nothing instead of the logging statement.


#### $aif/$awhen

Equivalents to `aif` and `awhen` for use in JS code. They're basically the same definition, except made with `defpsmacro` instead of `defmacro`.

#### $

Basic emulation of the jQuery selector. It doesn't do standalone jQuery functions. For instance, it won't do what you think if you try `($ (map (list 1 2 3) (lambda (a) (+ 1 a))))`. But it will do what you think if you try `($ "#test" (val))`.

#### $exists?

Macro that formalizes an `exists?` check for jQuery elements. Takes a selector, returns true if any elements matching the selector exist.

Example:

      (if ($exists? sel)
          ($ sel (replace (render-table-entry (@ ev table))))
          (render-table-entry (@ ev table)))


#### $val

Takes a selector. Returns either the result of calling `.text()` or `.val()` on the selected element as appropriate. It's not really common to use it directly, but if you wanted to, you could

      ($val "#foo")

#### $int/$float

Tries to parse the value of the target element as an integer or float, depending on which one you call.

Example:

      ($ trg (text (min 4096 (+ 1 ($int trg)))))

#### doc-ready

Shorthand for `($ document (ready (lambda () ...)))`. You'd use it by doing `(doc-ready ...)`.

#### $map

Interface to the jQuery `$.map`. Takes a `body` argument rather than a function. That body will be evaluated with the symbols `elem` and `i` bound to the appropriae values. 

Example:

    ($map (list 3 2 1) (list i elem))
    
will return `[[0 3] [1 2] [2 1]]`. I've found that in most places, it's about as easy to use `loop`.

#### $grep

Interface to the jQuery `$.grep`. Takes a body rather than a function just like `$map`.

#### $get/$post

Interface to the `$.get` and `$post` functions. Takes a `uri`, an object of parameters and a `body`. There are four bound symbols in body:

- `data`, which refers to the raw return from the handler (doesn't seem to work in all browsers)
- `status` the HTTP response code
- `jqXHR`, the jquery response JSON object
- `res`, a parsed JSON object of the response text when possible

I tend not to use these directly, instead defining higher level constructs to do ajax calls for me, but if I did, it would look something like

      ($post "/target/page (:foo 1 :bar 2) 
             (log res))

#### $upload

A way to do async uploads as of HTML5. It expects you to pass it a form rather than a file, which is why you can't do this using a vanilla `$post` call, but it's still a damn sight easier than async uploads used to be.

Example:

      ;; somewhere in the HTML
      (:form :id "load-deck-form" :enctype "multipart/form-data"
             (:span :class "label" "Load: ") (:input :name "deck" :type "file"))
	     
      ;; then in the JS
      ($ "#load-deck-form" 
         (change (fn ($upload "#load-deck-form" "/load-deck"
                              (load-deck-for-editing res)))))

#### $highlight

Shorthand for `($ "#foo" (stop t t) (effect :highlight nil 500))`. 

Example:

      ($highlight "#card")

#### $append/$prepend/$replace

They're similar enough that I'll cover them all together. They each take a target and some `cl-who` markup, and do the appropriate thing. Example of use:

      ($prepend "#decks-tab" (:div :class "new-deck new-custom-deck" 
				   :title deck-name deck-name))
				   
The other two have the same argument signatures, and only slight differences in behavior;

 - `$prepend` replaces the target with the specified markup
 - `$append` adds the specified markup to the end of the target
 - `$prepend` adds the specified markup to the beginning of the target

#### $droppable

Interface to `.droppable`.

Example:

    ($droppable board-selector (:overlapping ".foo")
	(:card-in-hand 
	 (play ($ dropped (attr :id)) :up (@ event client-x) (@ event client-y) 0 0)))

This will run the code `(play ...` when a `draggable` with the class `card-in-hand` is dropped on it. When the draggable is entered, all draggables with class `foo` will be temporarily disabled until this draggable is exited.

#### $draggable

Interface to `draggable`.

Example:

    ($draggable ".foo" () 
	(move (self id) (@ ui offset left) (@ ui offset top) 0 0))

This creates a draggable for the class `.foo`, and runs `(move...` when dragging stops.

#### $keydown

Interface to `.keydown()`. Binds the symbols `shift?`, `alt?`, `ctrl?` and `meta?` to the appropriate modifier key check. Binds the symbols `<ret>`, `<esc>`, `<space>`, `<up>`, `<down>`, `<left>` and `<right>` to the appropriate key codes. Accepts single-letter strings instead of keycodes for the other keys.

Example:

      ($keydown "#new-table-setup .game-tag" 
		<ret> ($ "#new-table-setup .ok" (click))
		<esc> ($ "#new-table-setup .cancel" (click)))

#### $on

Interface to `.on()`, but only deals with the delegation situation. 

Example:

     ($on "#deck-editor"
	  (:click "button.remove" ($ this (parent) (remove)))
	  (:click "button.add" ($ "#deck-editor .cards" (append ($ this (parent) (clone))))))

#### $button

Interface to `.button()`, and optionally also defines a `.click()` event as well. Example use:

      ($button "#zoomed-card button.hide" (:zoomout) ($ "#zoomed-card" (hide)))
      
if you want to create a button with no click event, just omit that last part.

      ($button "#zoomed-card button.hide" (:zoomout))

#### $click/$right-click

Interface to `.click()`. It takes a list of `selector/body`. It runs the body when a thing of the appropriate selector is clicked.

Example:

      ($click "#game .join" (lobby/join-table id ""))

The `$right-click` macro is called exactly the same way, but I should note that I've stopped using it.
