;;; my-keys.el --- Optimized keybindings -*- lexical-binding: t; -*-
;; ======================================
;;; Helper Functions
;; ======================================
(defmacro my/defkeymap (name map-name &rest bindings)
  "Define keymap with NAME and BINDINGS, automatically setting up which-key labels."
  (declare (indent 2))
  `(progn
     (defvar-keymap ,name
       :name ,map-name
       ,@(mapcan (lambda (binding)
                   (list (car binding) (caddr binding)))
                 bindings))
     (which-key-add-keymap-based-replacements ,name
       ,@(mapcan (lambda (binding)
                   (list (car binding) (cadr binding)))
                 bindings))))

(defun my/prefix-with-ime-deactivation ()
  "Show master keymap."
  (interactive)
  (which-key-show-keymap 'my-emacs-prefix-map my-emacs-prefix-map)
  (set-transient-map my-emacs-prefix-map nil nil))

;; ======================================
;;; Keymap Definitions
;; ======================================
(my/defkeymap my-edit-prefix-map "Edit"
  ("i" "Indent dwim"        #'my/simple-indent-dwim)
  ("r" "Regexp replace"     #'my/query-replace-regexp-dwim)
  ("c" "Current line"       #'my/select-current-line)
  ("d" "Duplicate"          #'my/duplicate-dwim)
  ("p" "buffer2PDF"         #'my/buffer-to-pdf-pandoc)
  ("w" "Pairs wrap"         #'my/pair-pairs-wrap)
  ("%" "Replace"            #'query-replace))

(my/defkeymap my-search-prefix-map "Search"
  ("g" "Grep"               #'consult-grep)
  ("l" "Line"               #'consult-line)
  ("o" "Outline"            #'consult-outline)
  ("u" "Unified search"     #'my/search-unified)
  ("m" "Imenu"              #'consult-imenu))

(my/defkeymap my-life-prefix-map "Life"
  ("l" "Lunar date"         #'my/show-lunar-date)
  ("p" "todays Pop"         #'my/todays-pop)
  ("t" "Tide info"          #'my/show-tide-info)
  ("q" "random Quote"       #'my/show-random-quote)
  ("w" "weather"            #'my/show-weather)
  ("W" "Bp week stats"      #'my/bp-report)
  ("T" "Bp tag stats"       #'my/show-bp-stats-by-tag))

(my/defkeymap my-media-prefix-map "Media"
  ("c" "Caffeine on"        #'my/caffeine-on)
  ("C" "Caffeine off"       #'my/caffeine-off)
  ("P" "Play radio"         #'my/radio-play)
  ("S" "Stop radio"         #'my/radio-stop)
  ("i" "Insert img"         #'my/org-insert-image)
  ("I" "Insert img manual"  #'my/org-insert-image-manual)
  ("s" "Screenshot"         #'my/org-screenshot))

(my/defkeymap my-window-prefix-map "Window"
  ("j" "Width 1/3-2/3"      #'my/toggle-window-split-ratio)
  ("i" "Height 1/3-2/3"     #'my/toggle-window-height-ratio)
  ("k" "Pin/Unpin"          #'my/toggle-window-dedicated)
  ("l" "3-Win Layout"       #'my/layout-3-windows-center-focus)
  ("m" "Split 3-Column"     #'my/split-window-three-column))

(my/defkeymap my-emacs-prefix-map "Master"
  ("e" "Edit"               my-edit-prefix-map)
  ("l" "Life"               my-life-prefix-map)
  ("m" "Media"              my-media-prefix-map)
  ("r" "Register"           #'jump-to-register)
  ("s" "Search"             my-search-prefix-map)
  ("w" "Window"             my-window-prefix-map))

(provide 'my-keys)
;;; my-keys.el ends here
