;;; hy-keys.el --- Optimized keybindings -*- lexical-binding: t; -*-
;;
;;
;; ======================================
;;; Helper Functions
;; ======================================
(defmacro hy/defkeymap (name map-name &rest bindings)
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

(defun hy/prefix-with-ime-deactivation ()
  "Show master keymap."
  (interactive)
  (which-key-show-keymap 'hy-emacs-prefix-map hy-emacs-prefix-map)
  (set-transient-map hy-emacs-prefix-map nil nil))

;; ======================================
;;; Keymap Definitions
;; ======================================
(hy/defkeymap hy-edit-prefix-map "Edit"
  ("i" "Indent dwim"         #'hy/simple-indent-dwim)
  ("r" "Regexp replace"      #'hy/query-replace-regexp-dwim)
  ("l" "current Line"        #'hy/select-current-line)
  ("d" "Duplicate"           #'duplicate-dwim)
  ("o" "Open newline below"  #'hy/open-line-below)
  ("p" "buffer2PDF"          #'hy/buffer-to-pdf-pandoc)
  ("u" "Unfill paragraph"    #'hy/unfill-paragraph)
  ("%" "Replace"             #'query-replace))

(hy/defkeymap hy-finishing-prefix-map "Finishing"
  ("c" "strip pair Content"  #'hy/strip-pair-with-content)
  ("h" "manage Hanja"        #'hy/manage-hanja-annotations)
  ("q" "normalize Quotes"    #'hy/normalize-quotes)
  ("w" "Pairs (u)wrap"       #'hy/pair-pairs-wrap)
  ("W" "tidy-Witespace"      #'hy/tidy-whitespace))

(hy/defkeymap hy-org-prefix-map "ORG"
  ("b" "insert-prefix-Block" #'hy/org-insert-custom-prefix-to-blocks)
  ("d" "insert-Drawer"       #'hy/org-insert-drawer-custom)
  ("e" "toggle-emphasis"     #'hy/org-toggle-emphasis-markers)
  ("i" "insert Img"          #'hy/org-insert-image)
  ("I" "insert Img manual"   #'hy/org-insert-image-manual)
  ("l" "insert-Link-dwim"    #'hy/org-insert-link-dwim))
  
(hy/defkeymap hy-search-prefix-map "Search"
  ("g" "Grep"                #'consult-grep)
  ("l" "Line"                #'consult-line)
  ("o" "Outline"             #'consult-outline)
  ("u" "Unified search"      #'hy/search-unified)
  ("m" "iMenu"               #'consult-imenu))

(hy/defkeymap hy-life-prefix-map "Life"
  ("l" "Lunar date"          #'hy/show-lunar-date)
  ("p" "todays Pop"          #'hy/todays-pop)
  ("t" "Tide info"           #'hy/show-tide-info)
  ("q" "random Quote"        #'hy/show-random-quote)
  ("w" "weather"             #'hy/show-weather)
  ("W" "Bp week stats"       #'hy/bp-report)
  ("T" "Bp tag stats"        #'hy/show-bp-stats-by-tag))

(hy/defkeymap hy-media-prefix-map "Media"
  ("P" "Play radio"          #'hy/radio-play)
  ("S" "Stop radio"          #'hy/radio-stop))
  ;; ("s" "Screenshot"          #'hy/org-screenshot))

(hy/defkeymap hy-window-prefix-map "Window"
  ("c" "Caffeine on"         #'hy/caffeine-on)
  ("C" "Caffeine off"        #'hy/caffeine-off)
  ("j" "Width 1/3-2/3"       #'hy/toggle-window-split-ratio)
  ("i" "Height 1/3-2/3"      #'hy/toggle-window-height-ratio)
  ("k" "Pin/Unpin"           #'hy/toggle-window-dedicated)
  ("l" "3-Win Layout"        #'hy/layout-3-windows-center-focus)
  ("m" "Split 3-Column"      #'hy/split-window-three-column)
  ("n" "sidebar layout-20"   #'hy/toggle-sidebar-layout-20))

(hy/defkeymap hy-emacs-prefix-map "Master"
  ("e" "Edit"                hy-edit-prefix-map)
  ("f" "Finishing"           hy-finishing-prefix-map)
  ("l" "Life"                hy-life-prefix-map)
  ("m" "Media"               hy-media-prefix-map)
  ("o" "ORG"                 hy-org-prefix-map)
  ("r" "Register"            #'jump-to-register)
  ("s" "Search"              hy-search-prefix-map)
  ("w" "Window"              hy-window-prefix-map))

(provide 'hy-keys)
;;; hy-keys.el ends here
