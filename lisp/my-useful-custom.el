;;; -*- lexical-binding: t; -*-
;; .emacs.d/lisp/my-useful-custom.el


;;; ###autoload
;; (defun my-today-stamp ()
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
(defun my/select-current-line ()
 "Select the entire current line as an active region."
  (interactive)
  (beginning-of-line)
  (set-mark (point))
  (end-of-line))


;;; ###autoload
;; (defun my/duplicate-dwim ()
;;   "Duplicate the current region if active, otherwise duplicate the current line."
;;   (interactive)
;;   (let ((use-region (use-region-p)))
;;     (save-excursion
;;       (let ((text (if use-region
;;                       (buffer-substring (region-beginning) (region-end))
;;                     (filter-buffer-substring (line-beginning-position) (line-end-position)))))
;;         (goto-char (if use-region (region-end) (line-end-position)))
;;         (newline)
;;         (insert text)))
;;     ;; Move cursor to the next line for consecutive duplication
;;     (forward-line 1)))


;;; ###autoload
(defun my/query-replace-regexp-dwim (arg)
  "Replace in region if active, else in whole buffer."
  (interactive "P")
  (let ((start (if (use-region-p) (region-beginning) (point-min)))
        (end (if (use-region-p) (region-end) (point-max))))
    (save-excursion
      (goto-char start)
      (call-interactively #'query-replace-regexp))))


;; (defun my/deactivate-input-method (&rest _args)
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
(defun my/simple-indent-dwim ()
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


(defun my/emacs-copyright ()
  "Return Emacs copyright with current year."
  (format "Copyright © 1996-%s,  Free Software Foundation, Inc."
          (format-time-string "%Y")))


(defun my/keyboard-quit-dwim ()
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


(defun my/smart-beginning-of-line ()
  "Move point to first non-whitespace character or `beginning-of-line'."
  (interactive)
  (let ((oldpos (point)))
    (call-interactively 'back-to-indentation)
    (and (<= oldpos (point))
	 (/= (line-beginning-position) oldpos)
	 (call-interactively 'beginning-of-line))))


;;; ###autoload
(defun my/paste-with-parentheses ()
  "Insert clipboard content enclosed in parentheses."
  (interactive)
  (let ((text (or (gui-get-selection 'CLIPBOARD 'STRING) (current-kill 0))))
    (if (and text (not (string-empty-p text)))
        (insert (format "(%s)" text))
      (message "Clipboard is empty."))))


;;;###autoload
(defun my/toggle-window-split-ratio ()
  "Toggle the current window's width between 1/3 and 2/3 of the frame.
Does not include 1/2 ratio; use `balance-windows' (C-x +) for equal splits.
Preserves all buffer contents during the resize."
  (interactive)
  (let* ((total-width (frame-width))
         (current-width (window-total-width))
         ;; 현재 비율이 50%보다 작으면 2/3로, 크면 1/3로 목표 설정
         (target-width (if (< (/ (float current-width) total-width) 0.5)
                           (round (* total-width 0.66))
                         (round (* total-width 0.33))))
         (delta (- target-width current-width)))
    (window-resize nil delta t)
    (message "Window width toggled (1/3 <-> 2/3)")))


;;;###autoload
(defun my/toggle-window-height-ratio ()
  "Toggle the current window's height between 1/3 and 2/3 of the frame.
This function preserves all buffer contents and works regardless of 
the number of open windows. It only adjusts the window's boundary."
  (interactive)
  (let* ((total-height (frame-height))
         (one-third (round (* total-height 0.33)))
         (two-thirds (round (* total-height 0.66)))
         (current-height (window-total-height))
         ;; 현재 높이가 1/3에 가까우면 2/3로, 아니면 1/3로 목표 설정
         (target-height (if (< (abs (- current-height one-third)) 
                              (abs (- current-height two-thirds)))
                           two-thirds
                         one-third))
         (delta (- target-height current-height)))
    ;; window-resize의 세 번째 인자가 nil이면 세로(높이) 조절입니다.
    (window-resize nil delta nil)
    (message "Window height toggled to approx %s" 
             (if (= target-height one-third) "1/3" "2/3"))))


;;;###autoload
(defun my/toggle-window-dedicated ()
  "Toggle whether the current window is dedicated to its current buffer.
A dedicated window will not be used by Emacs to display other buffers."
  (interactive)
  (set-window-dedicated-p (selected-window) (not (window-dedicated-p)))
  (message "Window is %s dedicated" 
           (if (window-dedicated-p) "NOW" "NO LONGER")))


;;;###autoload
(defun my/layout-3-windows-center-focus ()
  "Set a 25% | 50% | 25% layout for 3 windows, regardless of cursor position.
Windows are sorted by their horizontal position on the frame."
  (interactive)
  (let ((windows (window-list)))
    (if (= (length windows) 3)
        ;; 창들을 왼쪽 좌표(edges) 기준으로 정렬
        (let* ((sorted-windows (sort windows (lambda (w1 w2)
                                               (< (car (window-edges w1))
                                                  (car (window-edges w2))))))
               (total-width (frame-width))
               ;; (side-width (round (* total-width 0.25)))
               ;; (center-width (- total-width (* side-width 2)))
	       (side-width (round (* total-width 0.3)))
               (center-width (- total-width (* side-width 2)))
               (win-left (nth 0 sorted-windows))
               (win-center (nth 1 sorted-windows))
               (win-right (nth 2 sorted-windows)))
          
          ;; 1. 왼쪽 창 크기 고정
          (window-resize win-left (- side-width (window-total-width win-left)) t)
          ;; 2. 가운데 창 크기 조절 (나머지는 오른쪽 창이 됨)
          (window-resize win-center (- center-width (window-total-width win-center)) t)
          
          (message "Layout fixed: 25%% | 50%% | 25%% (Sorted by position)"))
      (message "Requires exactly 3 windows (current: %d)." (length windows)))))


;;;###autoload
(defun my/split-window-three-column ()
  "Split the current window into three columns with 25:50:25 ratio.
If more than one window exists, it will first delete other windows."
  (interactive)
  (delete-other-windows)
  ;; 1. 일단 3개로 분할
  (split-window-right)
  (split-window-right)
  ;; 2. 이전에 만든 25:50:25 레이아웃 함수 호출
  (my/layout-3-windows-center-focus)
  (message "Three-column layout initialized."))


(defun my/get-display-workarea ()
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
(defun my/tile-frame-left ()
  "Snap the Emacs frame to the Left half of the screen."
  (interactive)
  (let* ((area (my/get-display-workarea))
         (x      (nth 0 area))
         (y      (nth 1 area))
         (width  (nth 2 area))
         (height (nth 3 area))
         (half-w (/ width 2)))
    (set-frame-position nil x y)
    (set-frame-size nil half-w height t)) ; t = pixel 단위
  (message "◧ Moved to Left Half"))


;;;###autoload
(defun my/tile-frame-right ()
  "Snap the Emacs frame to the Right half of the screen."
  (interactive)
  (let* ((area (my/get-display-workarea))
         (x      (nth 0 area))
         (y      (nth 1 area))
         (width  (nth 2 area))
         (height (nth 3 area))
         (half-w (/ width 2)))
    (set-frame-position nil (+ x half-w) y)
    (set-frame-size nil half-w height t))
  (message "◨ Moved to Right Half"))


;;;###autoload
(defun my/tile-frame-center ()
  "Snap the Emacs frame to the center 2/3 of the screen."
  (interactive)
  (let* ((area   (my/get-display-workarea))
         (x      (nth 0 area))
         (y      (nth 1 area))
         (width  (nth 2 area))
         (height (nth 3 area))
         (two-thirds-w (/ (* width 2) 3))
         (offset-x    (/ (- width two-thirds-w) 2)))
    (set-frame-position nil (+ x offset-x) y)
    (set-frame-size nil two-thirds-w height t))
  (message "▣ center 2/3"))


;; (defun my/Bdays ()
;;   "Return the elapsed days of BP medication since 2024-12-31 as a string.
;; This is a helper function for Org-capture templates."
;;   (let* ((target-date (encode-time 0 0 0 4 3 2026)) ; 기준일: 2026년 3월 4일
;;          ;; 기준일을 1일로 포함하여 경과일 계산
;;          (diff-days (1+ (floor (/ (float-time (time-subtract (current-time) target-date)) 
;;                                   86400)))))
;;     (format "Day %d: BP 💊" diff-days)))


;;;###autoload
(defun my/caffeine-on ()
  "Prevent macOS from sleeping for a selected duration.
Prompts the user to choose between 30 minutes or 60 minutes.
Uses macOS built-in caffeinate command with -d flag to keep display awake."
  (interactive)
  (let* ((choice (completing-read "Caffeine duration: " '("30 min" "60 min")))
         (seconds (if (string= choice "30 min") 1800 3600)))
    (start-process "caffeinate" nil "caffeinate" "-d" "-t" (number-to-string seconds))
    (message "Caffeine ON for %s" choice)))


;;;###autoload
(defun my/caffeine-off ()
  "Allow macOS to sleep normally by terminating the caffeinate process.
Kills any running caffeinate process started by caffeine-on."
  (interactive)
  (shell-command "pkill caffeinate")
  (message "Caffeine OFF"))


;;;###autoload
(defun my/buffer-to-pdf-pandoc ()
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


(provide 'my-useful-custom)
;;; my-useful-custom.el ends here
