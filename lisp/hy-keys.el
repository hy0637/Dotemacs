;;; hy-keys.el --- Optimized keybindings -*- lexical-binding: t; -*-
;;
;; ver 20260705
;;
;; =====================================================================
;;; Helper Functions
;; =====================================================================
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


;; =====================================================================
;;; Keymap Definitions
;; =====================================================================
(hy/defkeymap hy-buffer-prefix-map "Buffer"
  ("n" "New buffer"           #'hy/create-new-empty-buffer)
  ("k" "Kill other buffer"    #'hy/kill-other-buffers))

(hy/defkeymap hy-edit-prefix-map "Edit"
  ("i" "Indent dwim"          #'hy/simple-indent-dwim)
  ("j" "Join next line"       #'hy/join-next-line)
  ("r" "Regexp replace"       #'hy/query-replace-regexp-dwim)
  ("l" "current Line"         #'hy/select-current-line)
  ("d" "Duplicate"            #'duplicate-dwim)
  ("o" "Open newline below"   #'hy/open-line-below)
  ("p" "buffer2PDF"           #'hy/buffer-to-pdf-pandoc)
  ("u" "Unfill paragraph"     #'hy/unfill-paragraph)
  ("%" "Replace"              #'query-replace))

(hy/defkeymap hy-finishing-prefix-map "Finishing"
  ;; ("h" "manage Hanja"         #'hy/manage-hanja-annotations)
  ("q" "normalize Quotes"     #'hy/normalize-quotes)
  ;; ("w" "Pairs (u)wrap"        #'hy/pair-pairs-wrap)
  ("w" "Pairs manage"         #'hy/pair-manage)
  ("W" "tidy-Witespace"       #'hy/tidy-whitespace))

(hy/defkeymap hy-org-prefix-map "ORG"
  ;; ("b" "insert-prefix-Block"  #'hy/org-insert-custom-prefix-to-blocks)
  ("d" "insert-Drawer"        #'hy/org-insert-drawer-custom)
  ("e" "toggle-emphasis"      #'hy/org-toggle-emphasis-markers)
  ("i" "insert Img"           #'hy/org-insert-image)
  ("I" "insert Img manual"    #'hy/org-insert-image-manual)
  ("l" "insert-Link-dwim"     #'hy/org-insert-link-dwim)
  ("m" "Mark-current-body"    #'hy/org-mark-current-body-only)
  ("s" "insert-Space-after"   #'hy/org-insert-space-after-punctuation))
  
(hy/defkeymap hy-search-prefix-map "Search"
  ("g" "Grep"                 #'consult-grep)
  ("l" "Line"                 #'consult-line)
  ("o" "Outline"              #'consult-outline)
  ("u" "Unified search"       #'hy/search-unified)
  ("m" "iMenu"                #'consult-imenu))

(hy/defkeymap hy-life-prefix-map "Life"
  ("l" "Lunar date"           #'hy/show-lunar-date)
  ("p" "todays Pop"           #'hy/todays-pop)
  ("t" "Tide info"            #'hy/show-tide-info)
  ("q" "random Quote"         #'hy/show-random-quote)
  ("w" "weather"              #'hy/show-weather)
  ("W" "Bp week stats"        #'hy/bp-report)
  ("T" "Bp tag stats"         #'hy/show-bp-stats-by-tag))

(hy/defkeymap hy-media-prefix-map "Media"
  ("P" "Play radio"           #'hy/radio-play)
  ("S" "Stop radio"           #'hy/radio-stop))

(hy/defkeymap hy-window-prefix-map "Window"
  ("c" "Caffeine on"          #'hy/caffeine-on)
  ("C" "Caffeine off"         #'hy/caffeine-off)
  ("s" "Sidebar layout-20"    #'hy/toggle-sidebar-layout-20)
  ("r" "window Resize"        #'hy/interactive-window-resize-all))

(hy/defkeymap hy-emacs-prefix-map "Master"
  ("b" "Buffer"               hy-buffer-prefix-map)
  ("e" "Edit"                 hy-edit-prefix-map)
  ("f" "Finishing"            hy-finishing-prefix-map)
  ("l" "Life"                 hy-life-prefix-map)
  ("m" "Media"                hy-media-prefix-map)
  ("o" "ORG"                  hy-org-prefix-map)
  ("r" "Register"             #'jump-to-register)
  ("s" "Search"               hy-search-prefix-map)
  ("w" "Window"               hy-window-prefix-map))


;; =====================================================================
;;; Overriding Minor Mode를 통한 M-SPC 마스터 키 보호 설정
;; =====================================================================

;; 1. 최상위 우선순위를 가질 오버라이딩 키맵 정의
(defvar hy-overrides-mode-map (make-sparse-keymap)
  "어떤 Major mode보다도 우선하여 작동할 최상위 단축키 맵.")

;; 2. 전역 마이너 모드 선언
(define-minor-mode hy-overrides-mode
  "hy-keys의 핵심 진입점 및 필수 단축키를 보호하는 전역 마이너 모드."
  :global t
  :init-value nil
  :keymap hy-overrides-mode-map)

;; 3. M-SPC 단축키를 이 오버라이딩 맵에 강제 지정
;; 어떤 Major mode(org-mode 등)에 있더라도, 한글 입력 상태와 상관없이 
;; M-SPC를 누르면 무조건 IME가 비활성화되면서 최상위 마스터 맵이 열립니다.
(define-key hy-overrides-mode-map (kbd "M-o") #'hy/prefix-with-ime-deactivation)

;; 4. 마이너 모드 활성화 (Emacs 구동 시 자동 켜짐)
(hy-overrides-mode 1)

(provide 'hy-keys)
;;; hy-keys.el ends here
