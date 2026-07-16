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


;;;###autoload
(defun hy/kill-other-buffers ()
  "현재 버퍼와 *scratch* 버퍼를 제외한 모든 버퍼 삭제."
  (interactive)
  (let ((current (current-buffer))
        (scratch (get-buffer "*scratch*"))
        (killed-count 0))
    (dolist (buf (buffer-list))
      ;; 현재 버퍼도 아니고, 스크래치 버퍼도 아니고, 버퍼 이름이 비어있지 않은 경우만 대상
      (unless (or (eq buf current)
                  (eq buf scratch)
                  (string-prefix-p " " (buffer-name buf))) ; 미니버퍼 등 내부 버퍼 제외
        (kill-buffer buf)
        (setq killed-count (1+ killed-count))))
    (message "🧹 %d개의 버퍼를 정리. (현재 버퍼와 *scratch*만 유지)" killed-count)))


;;;###autoload
(defun hy/create-new-empty-buffer ()
  "이름이 겹치지 않는 새로운 빈 버퍼 생성 ->전환"
  (interactive)
  (let ((new-buf (generate-new-buffer "*new-buffer*")))
    (switch-to-buffer new-buf)
    (funcall (default-value 'major-mode)) ; 기본 메이저 모드
    (message "새 버퍼가 생성되었습니다: %s" (buffer-name new-buf))))


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


;;;###autoload
(defun hy/org-insert-space-after-punctuation ()
  "특수기호(, . : ; \") 뒤에 공백 한 칸을 자동으로 삽입.
블록(Region)을 지정하면 해당 범위만 적용되고, 지정하지 않으면 버퍼 전체에 적용.
단, 여는 따옴표(“)는 대상에서 제외."
  (interactive)
  (let ((beg (if (use-region-p) (region-beginning) (point-min)))
        (end (if (use-region-p) (region-end) (point-max))))
    (save-excursion
      (goto-char beg)
      ;; 지정된 범위(end) 안에서만 정규식 매칭 수행.
      (while (re-search-forward "\\([,\\.:;\\”]\\)\\([^[:space:]\n]\\)" end t)
        (replace-match "\\1 \\2"))
      (if (use-region-p)
          (message "선택한 범위의 특수기호 뒤 공백 정돈 완료!")
        (message "버퍼 전체의 특수기호 뒤 공백 정돈 완료!")))))

;;  =============================================
;;; hy/repeat-last-mx-command(Excel F4)
;;  =============================================
(defun hy/repeat-last-mx-command ()
  "M-x 기록(vertico 상위)의 최신 명령을 영역 지정에 구애받지 않고 재실행."
  (interactive)
  (if (and (boundp 'extended-command-history) extended-command-history)
      (let ((last-cmd (intern (car extended-command-history))))
        (message "재실행 명령: M-x %s" last-cmd)
        (command-execute last-cmd))
    (message "안내: 아직 실행한 M-x 명령 기록이 없습니다.")))

  
  
(provide 'hy-useful-custom)
;;; hy-useful-custom.el ends here
