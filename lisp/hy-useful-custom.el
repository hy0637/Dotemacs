;;; -*- lexical-binding: t; -*-
;; .emacs.d/lisp/hy-useful-custom.el

(defun hy/emacs-copyright ()
  "Return Emacs copyright with current year."
  (format "Copyright © 1996-%s,  Free Software Foundation, Inc."
          (format-time-string "%Y")))


;;; ###autoload
;; (defun hy-today-stamp ()
;;   "Prompt for a date format and insert it at point."
;;   (interactive)
;;   (let* ((formats `(("ISO (YYYY-MM-DD)"       . "%Y-%m-%d")
;;                     ("Dot (YYYY.MM.DD)"       . "%Y.%m.%d")
;;                     ("DateTime (ISO + Time)"  . "%Y-%m-%d %R")
;;                     ("Weekday (ISO + Day)"    . ,(lambda () 
;;                                                    (format-time-string "%Y-%m-%d %A")))))
;;          (choice (completing-read "Select date format: " (mapcar #'car formats) nil t))
;;          (action (cdr (assoc choice formats))))
;;     (when action
;;       (if (functionp action)
;;           (insert (funcall action))
;;         (insert (format-time-string action))))))


;;; ###autoload
(defun hy/select-current-line ()
 "Select the entire current line as an active region."
  (interactive)
  (beginning-of-line)
  (set-mark (point))
  (end-of-line))


;;; ###autoload
(defun hy/open-line-below ()
  "Open a new line below the current line and move point there."
  (interactive)
  (end-of-line)
  (newline-and-indent))

(global-set-key (kbd "C-c o") 'hy/open-line-below)


;;; ###autoload
(defun hy/join-next-line ()
  "Join the current line with the following line."
  (interactive)
  (join-line 1))


;;; ###autoload
(defun hy/query-replace-regexp-dwim (arg)
  "Replace in region if active, else in whole buffer."
  (interactive "P")
  (let ((start (if (use-region-p) (region-beginning) (point-min)))
        (end (if (use-region-p) (region-end) (point-max))))
    (save-excursion
      (goto-char start)
      (call-interactively #'query-replace-regexp))))


;; (defun hy/deactivate-input-method (&rest _args)
;;   "Deactivate current input method."
;;   (when (and (boundp 'current-input-method) current-input-method)
;;     (deactivate-input-method)))


;;; ###autoload
;; (defun-open-in-finder ()
;;   "Open current file in Finder"
;;   (interactive)
;;   (shell-command (concat "open -R " (shell-quote-argument buffer-file-name))))


;;https://github.com/protesilaos/dotfiles
;;;###autoload
(defun hy/simple-indent-dwim ()
  "Indent the current defun in `prog-mode' or paragraph in `text-mode'."
  (interactive)
  (save-excursion
    (cond
     ((derived-mode-p 'prog-mode)
      (mark-defun))
     ((derived-mode-p 'text-mode)
      (mark-paragraph)))
    (indent-for-tab-command)
    (deactivate-mark)))


(defun hy/keyboard-quit-dwim ()
  "Do-what-I-mean quit behavior.
Handle 'keyboard-quit' based on the current context, such as an active region, open minibuffer,
or the Completions buffer."
  (interactive)
  (cond
   ((region-active-p)                      ; 1. 블록이 잡혀있으면 블록 해제
    (keyboard-quit))
   ((derived-mode-p 'completion-list-mode) ; 2. 완성 목록창이 떠 있으면 닫기
    (delete-completion-window))
   ((> (minibuffer-depth) 0)               ; 3. 미니버퍼가 열려있으면 (포커스 상관없이) 닫기
    (abort-recursive-edit))
   (t                                      ; 4. 그 외에는 일반적인 Quit
    (keyboard-quit))))


(defun hy/smart-beginning-of-line ()
  "Move point to first non-whitespace character or `beginning-of-line'."
  (interactive)
  (let ((oldpos (point)))
    (call-interactively 'back-to-indentation)
    (and (<= oldpos (point))
	 (/= (line-beginning-position) oldpos)
	 (call-interactively 'beginning-of-line))))


;;; ###autoload
(defun hy/paste-with-parentheses ()
  "Insert clipboard content enclosed in parentheses."
  (interactive)
  (let ((text (or (gui-get-selection 'CLIPBOARD 'STRING) (current-kill 0))))
    (if (and text (not (string-empty-p text)))
        (insert (format "(%s)" text))
      (message "Clipboard is empty."))))


;; --------------
;;; Window
;; --------------

(defun hy/get-display-workarea ()
  "Returns the usable work area of the current monitor,
excluding the Dock and Menu bar."
  (let* ((attrs (frame-monitor-attributes))
         (workarea (alist-get 'workarea attrs)))
    ;; workarea: (x y width height)
    (list (nth 0 workarea)
          (nth 1 workarea)
          (nth 2 workarea)
          (nth 3 workarea))))


;;;###autoload
(defun hy/tile-frame-left ()
  "Snap the Emacs frame to the Left half of the screen."
  (interactive)
  (let* ((area (hy/get-display-workarea))
         (x      (nth 0 area))
         (y      (nth 1 area))
         (width  (nth 2 area))
         (height (nth 3 area))
         (half-w (/ width 2)))
    (set-frame-position nil x y)
    (set-frame-size nil half-w height t)) ; t = pixel 단위
  (message "◧ Moved to Left Half"))


;;;###autoload
(defun hy/tile-frame-right ()
  "Snap the Emacs frame to the Right half of the screen."
  (interactive)
  (let* ((area (hy/get-display-workarea))
         (x      (nth 0 area))
         (y      (nth 1 area))
         (width  (nth 2 area))
         (height (nth 3 area))
         (half-w (/ width 2)))
    (set-frame-position nil (+ x half-w) y)
    (set-frame-size nil half-w height t))
  (message "◨ Moved to Right Half"))


;;;###autoload
(defun hy/tile-frame-center ()
  "Snap the Emacs frame to the center 2/3 of the screen."
  (interactive)
  (let* ((area   (hy/get-display-workarea))
         (x      (nth 0 area))
         (y      (nth 1 area))
         (width  (nth 2 area))
         (height (nth 3 area))
         (two-thirds-w (/ (* width 2) 3))
         (offset-x    (/ (- width two-thirds-w) 2)))
    (set-frame-position nil (+ x offset-x) y)
    (set-frame-size nil two-thirds-w height t))
  (message "▣ center 2/3"))


;;;###autoload
(defun hy/toggle-sidebar-layout-20 ()
  "Set the leftmost window's width to exactly 20% of the frame.
If only one window exists, it automatically splits the window right (C-x 3)
and adjusts the left window to 20% and the right window to 80%."
  (interactive)
  (let ((windows (window-list)))
    ;; 1. 창이 1개인 경우 자동으로 우측 분할 처리
    (when (= (length windows) 1)
      (split-window-right)
      (setq windows (window-list))) ; 분할 후 창 목록 갱신
    
    ;; 2. 가장 왼쪽에 배치된 창 찾기
    (let* ((leftmost-window (car (sort windows (lambda (w1 w2)
                                                 (< (car (window-edges w1))
                                                    (car (window-edges w2)))))))
           (total-width (frame-width))
           (target-width (round (* total-width 0.20)))
           (current-width (window-total-width leftmost-window))
           (delta (- target-width current-width)))
      
      ;; 3. 가장 왼쪽 창을 잠시 안전하게 선택하여 크기를 정확히 조절
      (save-selected-window
        (select-window leftmost-window)
        (condition-case nil
            (window-resize leftmost-window delta t)
          (error
           ;; window-resize가 실패할 경우를 대비한 하드웨어 스케일러 백업
           (adjust-window-trailing-edge leftmost-window delta t))))
      
      (message "Sidebar layout fixed: Left window allocated 20%% of frame"))))


;;;###autoload
(defun hy/interactive-window-resize-all ()
  "방향키(←/→/↑/↓)로 창의 너비와 높이 제한 없이 조절.
임시로 최소 크기 제한을 해제하여 원하는 만큼 자유롭게 축소."
  (interactive)
  (message "창 크기 조절: [←/→] 너비 조절, [↑/↓] 높이 조절 (종료: 다른 키)")
  (let ((window-min-width 1)
        (window-min-height 1)
        (window-size-fixed nil))
    (set-transient-map
     (let ((map (make-sparse-keymap)))
       ;; 가로(너비) 조절
       (define-key map (kbd "<left>")
                   (lambda () (interactive)
                     (let ((window-min-width 1)) (window-resize nil -3 t))
                     (hy/interactive-window-resize-all)))
       (define-key map (kbd "<right>")
                   (lambda () (interactive)
                     (let ((window-min-width 1)) (window-resize nil 3 t))
                     (hy/interactive-window-resize-all)))
       ;; 세로(높이) 조절
       (define-key map (kbd "<up>")
                   (lambda () (interactive)
                     (let ((window-min-height 1)) (window-resize nil -3 nil))
                     (hy/interactive-window-resize-all)))
       (define-key map (kbd "<down>")
                   (lambda () (interactive)
                     (let ((window-min-height 1)) (window-resize nil 3 nil))
                     (hy/interactive-window-resize-all)))
       map))))
(global-set-key (kbd "C-x {") #'hy/interactive-window-resize-all)


;;;###autoload
(defun hy/caffeine-on ()
  "Prevent macOS from sleeping for a selected duration.
Prompts the user to choose between 30 minutes or 60 minutes.
Uses macOS built-in caffeinate command with -d flag to keep display awake."
  (interactive)
  (let* ((choice (completing-read "Caffeine duration: " '("30 min" "60 min")))
         (seconds (if (string= choice "30 min") 1800 3600)))
    (start-process "caffeinate" nil "caffeinate" "-d" "-t" (number-to-string seconds))
    (message "Caffeine ON for %s" choice)))


;;;###autoload
(defun hy/caffeine-off ()
  "Allow macOS to sleep normally by terminating the caffeinate process.
Kills any running caffeinate process started by caffeine-on."
  (interactive)
  (shell-command "pkill caffeinate")
  (message "Caffeine OFF"))


;;;###autoload
(defun hy/simple-delete-window-dwim ()
  ;;https://github.com/protesilaos
  "Do What I Mean to delete the current THING.
When there is more than one window, THING is a window.
When there are more than one `tab-bar-mode' tabs, THING is a tab.
Else THING is a frame if frames are more than one."
  (declare (interactive-only t))
  (interactive)
  (cond
   ((length> (window-list) 1)
    (delete-window))
   ((and (featurep 'tab-bar)
         (length> (tab-bar-tabs) 1))
    (tab-close))
   ((length> (frame-list) 1)
    (delete-frame))
   (t
    (user-error "Nothing to delete"))))

;;; =============


;;;###autoload
(defun hy/buffer-to-pdf-pandoc ()
  "Convert the current buffer to PDF using Pandoc.
Code files (.el, .py, .sh, etc.) are wrapped in a Markdown code block
and converted via a temporary .md file, which is deleted after conversion.
Other formats (.org, .md, etc.) are passed directly to Pandoc.
Requires pandoc and xelatex to be installed."
  (interactive)
  (let* ((input (buffer-file-name))
         (ext (and input (file-name-extension input)))
         (output (and input (concat (file-name-sans-extension input) ".pdf")))
         (code-exts '("el" "py" "sh" "js" "ts" "rb" "c" "h" "swift"))
         (pandoc-cmd
          (lambda (src)
            (format (concat "pandoc %s -o %s"
                            " --pdf-engine=xelatex"
                            " --highlight-style=tango"
                            " -V mainfont='KoPubWorldBatang'"
                            " -V sansfont='KoPubWorldDotum'"
                            " -V monofont='D2Coding'"
                            " -V geometry:margin=1.5cm"
			    " -V linestretch=1.4")
                    src output))))
    (cond
     ((null input)
      (message "Buffer is not associated with a file."))
     ((member ext code-exts)
      (let ((tmp-md (make-temp-file "emacs-print-" nil ".md")))
        (with-temp-file tmp-md
          (insert (format "# %s\n\n```%s\n"
                          (file-name-nondirectory input)
                          (cond ((string= ext "el") "scheme")
                                (t ext))))
          (insert-file-contents input)
          (goto-char (point-max))
          (insert "\n```\n"))
        (unwind-protect
            (call-process-shell-command (funcall pandoc-cmd tmp-md) nil nil nil)
          (delete-file tmp-md))))
     (t
      (call-process-shell-command (funcall pandoc-cmd input) nil nil nil)))
    (when output
      (shell-command (format "open %s" (shell-quote-argument output)))
      (message "PDF saved: %s" output))))


;;;###autoload
(defun hy/unfill-paragraph ()
  "Join the current paragraph (or region) into single lines."
  (interactive)
  (let ((fill-column most-positive-fixnum))
    (if (use-region-p)
        (fill-region (region-beginning) (region-end))
      (fill-paragraph))))


;;;###autoload
(defun hy/tidy-whitespace (beg end)
  "Clean up whitespace in region or whole buffer:
trailing spaces, doubled spaces, and excess blank lines."
  (interactive
   (if (use-region-p)
       (list (region-beginning) (region-end))
     (list (point-min) (point-max))))
  (let ((count 0)
        (end-marker (copy-marker end)))
    (save-excursion
      ;; 행끝 공백
      (goto-char beg)
      (while (re-search-forward "[ \t]+$" end-marker t)
        (replace-match "") (setq count (1+ count)))
      ;; 본문 속 이중 공백 (들여쓰기는 보호)
      (goto-char beg)
      (while (re-search-forward "\\([^ \t\n]\\)[ ]\\{2,\\}" end-marker t)
        (replace-match "\\1 ") (setq count (1+ count)))
      ;; 3연속 이상 빈 줄 → 1개로
      (goto-char beg)
      (while (re-search-forward "\n\\{3,\\}" end-marker t)
        (replace-match "\n\n") (setq count (1+ count))))
    (set-marker end-marker nil)
    (when (use-region-p)
      (setq deactivate-mark nil))
    (message "공백 %d곳 정돈" count)))


;;;###autoload
(defun hy/normalize-quotes (beg end &optional reverse)
  "Convert straight quotes to curly quotes in region or whole buffer.
With a prefix argument REVERSE (e.g., C-u), convert curly quotes back to straight quotes.
Automatically skips Org-mode src blocks to prevent code syntax errors."
  (interactive
   (let ((r-beg (if (use-region-p) (region-beginning) (point-min)))
         (r-end (if (use-region-p) (region-end) (point-max))))
     (list r-beg r-end current-prefix-arg)))
  (let ((count 0)
        (end-marker (copy-marker end)))
    (save-excursion
      (goto-char beg)
      (if reverse
          ;; [반대 동작] 둥근 따옴표 -> 곧은 따옴표
          (while (re-search-forward "[“”‘’]" end-marker t)
            ;; Org-mode 소스 블록 내부라면 건너뜀
            (unless (and (derived-mode-p 'org-mode)
                         (eq (org-element-type (org-element-at-point)) 'src-block))
              (let ((ch (char-before)))
                (replace-match
                 (cond ((memq ch '(?“ ?”)) "\"")
                       (t "'")))
                (setq count (1+ count)))))
        ;; [기존 동작] 곧은 따옴표 -> 둥근 따옴표
        (while (re-search-forward "[\"']" end-marker t)
          ;; Org-mode 소스 블록 내부라면 건너뜀
          (unless (and (derived-mode-p 'org-mode)
                       (eq (org-element-type (org-element-at-point)) 'src-block))
            (let* ((ch    (char-before))
                   (prev  (char-before (1- (point))))
                   (openp (or (null prev)
                              (memq prev '(?\s ?\t ?\n ?\( ?\[ ?{ ?“ ?‘)))))
              (replace-match
               (cond ((and (eq ch ?\") openp) "“")
                     ((eq ch ?\")             "”")
                     ((and (eq ch ?')  openp) "‘")
                     (t                       "’")))
              (setq count (1+ count)))))))
    (set-marker end-marker nil)
    ;; 원래 지정되어 있던 영역(Region)의 활성화 상태를 강제로 유지.
    (when (use-region-p)
      (setq deactivate-mark nil))
    (message "%s 따옴표 %d개 변환 완료" (if reverse "곧은" "둥근") count)))




(provide 'hy-useful-custom)
;;; hy-useful-custom.el ends here
