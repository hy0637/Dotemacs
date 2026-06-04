;;; hy-org-custom.el --- Optimized Org-mode configuration -*- lexical-binding: t; -*-
;;; 20260417
;;; Commentary:
;; Personal Org-mode configuration with centralized file paths and health tracking.

;;; Code:

;; ======================================
;;; 1. Variables & File Paths
;; ======================================
(defvar hy/org-person-dir (dropbox/dir "Person/")
  "Directory for personal org files.")

(defvar hy/f-daily  (expand-file-name "Daily.org"    hy/org-person-dir))
(defvar hy/f-tasks  (expand-file-name "Tasks.org"    hy/org-person-dir))
(defvar hy/f-health (expand-file-name "Health.org"   hy/org-person-dir))
(defvar hy/f-read   (expand-file-name "cReading.org" hy/org-person-dir))
(defvar hy/f-money  (expand-file-name "aMoney.org"   hy/org-person-dir))

(defvar hy/pngpaste-bin
  (or (executable-find "pngpaste") "/opt/homebrew/bin/pngpaste")
  "pngpaste executable path.")

(defvar hy/bp-start-date (encode-time 0 0 0 4 3 2026) "BP💊 start date.")


;; ======================================
;;; 2. Helper Functions
;; ======================================
(defvar hy/org-last-inserted-image nil
  "Last image file inserted by hy/org-insert-image.")


;;; ###autoload
(defun hy/org-insert-image (&optional manual)
  "Insert an image. If MANUAL, select manually ignoring history."
  (interactive "P")
  (let* ((choice (completing-read "Insert type: " '("inline" "path") nil t))
         (base-dir (expand-file-name "img/" org-directory))
         (prev-file (unless manual hy/org-last-inserted-image))
         (prev-ts (when prev-file
                    (and (string-match "_\\([0-9]+\\)\\." (file-name-nondirectory prev-file))
                         (match-string 1 (file-name-nondirectory prev-file)))))
         (prev-dir (when prev-file (file-name-directory prev-file)))
         (candidates (when prev-dir
                       (seq-filter (lambda (f)
                                     (and (not (file-directory-p f))
                                          (string-match "_\\([0-9]+\\)\\." (file-name-nondirectory f))))
                                   (directory-files prev-dir t))))
         (auto-file (when (and prev-ts candidates)
                      (seq-reduce
                       (lambda (acc f)
                         (let ((ts (and (string-match "_\\([0-9]+\\)\\." (file-name-nondirectory f))
                                        (match-string 1 (file-name-nondirectory f)))))
                           (if (and ts (string> ts prev-ts)
                                    (or (null acc)
                                        (string< ts (and (string-match "_\\([0-9]+\\)\\." (file-name-nondirectory acc))
                                                         (match-string 1 (file-name-nondirectory acc))))))
                               f acc)))
                       candidates nil)))
         (file (read-file-name "Select image: "
                               (or prev-dir base-dir)
                               nil t
                               (when auto-file (file-name-nondirectory auto-file)))))
    (when (and file (not (file-directory-p file)))
      (setq hy/org-last-inserted-image file)
      (pcase choice
        ("inline" (insert (format "[[file:%s]]\n" file)) (org-display-inline-images))
        ("path"   (insert (concat "./" (file-relative-name file))))))))


(defun hy/org-insert-image-manual ()
  "Insert image manually, ignoring history."
  (interactive)
  (hy/org-insert-image t))


;;; ###autoload
;; (defun hy/org-screenshot (chdir name)
;;   "Insert a screenshot from clipboard. Requires: brew install pngpaste"
;;   (interactive
;;    (let* ((default-dir (file-name-concat org-directory "img/"))
;;           (chosen-dir  (read-directory-name "Target directory: " default-dir default-dir t))
;;           (default-name (format-time-string "%Y%m%d_%H%M%S"))
;;           (file-name    (read-string (format "Enter filename (default %s, exclude extension): "
;;                                              default-name) nil nil default-name)))
;;      (list chosen-dir file-name)))
;;   (let ((path (expand-file-name (concat name ".png") chdir)))
;;     (make-directory chdir t)
;;     (if (zerop (shell-command (format "%s %s" hy/pngpaste-bin (shell-quote-argument path))))
;;         (progn
;;           (insert (format "\n#+ATTR_LATEX: :width 0.5\\textwidth\n#+CAPTION: %s\n[[file:%s]]\n" name path))
;;           (org-display-inline-images)
;;           (message "Image saved: %s" path))
;;       (error "No image in clipboard or pngpaste failed"))))


;;; ###autoload
(defun hy/org-insert-drawer-custom (&optional arg drawer)
  "Prompt and insert a drawer from an expanded list."
  (interactive "P")
  (org-insert-drawer arg
    (or drawer
        (completing-read "Drawer name: "
                         '("PROPERTIES" "LOGBOOK" "MEMO" "NOTE" "CONTEXT" "DETAIL" "SOLUTION")
                         nil nil))))


(defun hy/org-latex-filter-blocks (text backend info)
  "Apply global style to quote/verse blocks based on :quote-style option."
  (when (org-export-derived-backend-p backend 'latex)
    (let* ((style (plist-get info :quote-style))
           (template (cdr (assoc style
                                 '(("1" . "{\\small\n%s}")
                                   ("2" . "\\begin{tcolorbox}[colback=gray!10, boxrule=0.5pt, arc=0pt]\\small\n%s\\end{tcolorbox}")
                                   ("3" . "\\begin{tcolorbox}[colback=gray!10, boxrule=0.5pt, arc=0pt]\n%s\\end{tcolorbox}")
                                   ("4" . "\\begin{tcolorbox}[colback=gray!10, boxrule=0pt, arc=0pt]\\small\n%s\\end{tcolorbox}")
                                   ("5" . "\\begin{tcolorbox}[colback=gray!10, boxrule=0pt, arc=0pt]\n%s\\end{tcolorbox}"))))))
      (if template (format template text) text))))


;;; ###autoload
(defun hy/org-wrap-with-symbol-smart (char)
  "선택 영역을 기호 쌍으로 감쌉니다.
- 'm' 또는 '-' 입력 시: [기호][공백][영역][공백][기호]
- '\"' 또는 '`' 입력 시: [여는 따옴표][영역][닫는 따옴표]"
  (interactive (list (read-char "기호 입력 (', \", -, m): ")))
  (let* ((start (region-beginning))
         (end (region-end))
         (prefix "")
         (suffix ""))
    (cond
     ;; 1. 쌍따옴표 처리
     ((equal char ?\")
      (setq prefix (string #x201c) suffix (string #x201d)))
     ;; 2. 홑따옴표 처리
     ((equal char ?')
      (setq prefix (string #x2018) suffix (string #x2019)))
     ;; 3. 대시(Em-dash) 처리
     ((equal char ?m)
      (setq prefix "— " suffix " —"))
     ;; 4. 하이픈 처리
     ((equal char ?-)
      (setq prefix "- " suffix " -"))
     ;; 5. 그 외 기호는 앞뒤 동일하게
     (t
      (let ((s (char-to-string char)))
        (setq prefix s suffix s))))

    (save-excursion
      (goto-char end)
      (insert suffix)
      (goto-char start)
      (insert prefix))))



;;; ###autoload
(defun hy/org-insert-custom-prefix-to-blocks (beg end prefix)
  "선택 영역 내의 빈 줄이 아닌 줄 시작점에 사용자가 입력한 문자열(prefix)을 삽입합니다."
  (interactive "r\ns삽입할 문구를 입력하세요: ") ; r은 영역, s는 문자열 입력을 의미합니다.
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
      (goto-char (point-min))
      (while (not (eobp))
        ;; 현재 줄이 공백이 아니고, Org-mode 예약어(#+)로 시작하지 않을 때만 실행
        (when (and (not (looking-at "^\\s-*$"))
                   (not (looking-at "^[ \t]*#\\+")))
          (back-to-indentation)
          (insert prefix))
        (forward-line 1))))
  (deactivate-mark)
  (message "삽입 완료!" prefix))



;;; ###autoload
(defun hy/org-insert-link-dwim ()
;;https://github.com/hrs/dotfiles/blob/main/emacs/.config/emacs/configuration.org
  "Like `org-insert-link' but with personal dwim preferences."
  (interactive)
  (let* ((point-in-link (org-in-regexp org-link-any-re 1))
         (clipboard-url (when (and kill-ring
                                   (string-match-p "^http" (current-kill 0)))
                          (current-kill 0)))
         (region-content (when (region-active-p)
                           (buffer-substring-no-properties (region-beginning)
                                                           (region-end)))))
    (cond ((and region-content clipboard-url (not point-in-link))
           (delete-region (region-beginning) (region-end))
           (insert (org-make-link-string clipboard-url region-content))
           (message clipboard-url))
          ((and clipboard-url (not point-in-link))
           (insert (org-make-link-string
                    clipboard-url
                    (read-string "title: "
                                 (with-current-buffer (url-retrieve-synchronously clipboard-url)
                                   (dom-text (car
                                              (dom-by-tag (libxml-parse-html-region
                                                           (point-min)
                                                           (point-max))
                                                          'title))))))))
          (t
           (call-interactively 'org-insert-link)))))



;; ======================================
;;; 3. Health & Blood Pressure Logic
;; ======================================
(defun hy/bp-parse-table (&optional start-date end-date)
  "Parse Health.org BP table. Returns list of (sys dia pul) plists.
Optionally filter rows between START-DATE and END-DATE (encoded times)."
  (when (file-exists-p hy/f-health)
    (with-current-buffer (find-file-noselect hy/f-health)
      (save-excursion
        (save-restriction
          (widen)
          (goto-char (point-min))
          (let (rows)
            (while (re-search-forward
                    "^|\\s-*\\[\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)" nil t)
              (let* ((row-date (date-to-time (match-string 1)))
                     (cols (org-split-string (thing-at-point 'line) "|"))
                     (sys (and (> (length cols) 1) (string-to-number (string-trim (nth 1 cols)))))
                     (dia (and (> (length cols) 2) (string-to-number (string-trim (nth 2 cols)))))
                     (pul (and (> (length cols) 3) (string-to-number (string-trim (nth 3 cols))))))
                (when (and sys (> sys 0)
                           (or (not start-date) (time-less-p start-date row-date))
                           (or (not end-date)   (time-less-p row-date end-date)))
                  (push (list sys dia pul) rows))))
            rows))))))

;; (defun hy/bp-parse-table (&optional start-date end-date)
;;   "Parse Health.org BP table. Returns list of (sys dia pul) plists.
;; Optionally filter rows between START-DATE and END-DATE (encoded times)."
;;   (when (file-exists-p hy/f-health)
;;     (with-current-buffer (find-file-noselect hy/f-health)
;;       (org-with-wide-buffer
;;        (goto-char (point-min))
;;        (let (rows)
;;          (while (re-search-forward
;;                  "^|\\s-*\\[\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)" nil t)
;;            (let* ((row-date (date-to-time (match-string 1)))
;;                   (cols (org-split-string (thing-at-point 'line) "|"))
;;                   (sys (and (> (length cols) 1) (string-to-number (string-trim (nth 1 cols)))))
;;                   (dia (and (> (length cols) 2) (string-to-number (string-trim (nth 2 cols)))))
;;                   (pul (and (> (length cols) 3) (string-to-number (string-trim (nth 3 cols))))))
;;              (when (and sys (> sys 0)
;;                         (or (not start-date) (time-less-p start-date row-date))
;;                         (or (not end-date)   (time-less-p row-date end-date)))
;;                (push (list sys dia pul) rows))))
;;          rows)))))

(defun hy/bp-averages (&optional start-date end-date)
  "Return (avg-sys avg-dia avg-pul count) for BP rows in optional date range."
  (let ((rows (hy/bp-parse-table start-date end-date)))
    (when rows
      (let ((n (float (length rows))))
        (list (/ (apply '+ (mapcar #'car rows)) n)
              (/ (apply '+ (mapcar #'cadr rows)) n)
              (/ (apply '+ (mapcar #'caddr rows)) n)
              (length rows))))))

;; Public aliases kept for capture template compatibility
(defun hy/get-bp-stats ()
  "Overall BP averages from Health.org."
  (hy/bp-averages))


(defun hy/get-recent-bp-stats (days-offset &optional period)
  "Avg systolic for PERIOD days ending DAYS-OFFSET days ago."
  (let* ((period (or period 7))
         (end   (time-subtract (current-time) (days-to-time days-offset)))
         (start (time-subtract end (days-to-time period)))
         (rows  (hy/bp-parse-table start end)))
    (when rows (/ (apply '+ (mapcar #'car rows)) (float (length rows))))))


(defun hy/Bdays ()
  "Return string like 'BP💊 nD: 시간대/'."
  (let* ((diff-days (1+ (floor (/ (float-time (time-subtract (current-time) hy/bp-start-date)) 86400))))
         (hour (string-to-number (format-time-string "%H")))
         (time-tag (cdr (seq-find (lambda (x) (< hour (car x)))
                                  '((6 . "새벽") (12 . "오전") (14 . "점심")
                                    (18 . "오후") (21 . "저녁") (25 . "밤"))))))
    (format "BP %dD: %s/" diff-days time-tag)))
    ;; (format "BP💊 %dD: %s/" diff-days time-tag)))


(defun hy/bp-report ()
  "Display weekly BP report in echo area."
  (interactive)
  (let* ((this-week (hy/get-recent-bp-stats 0))
         (last-week (hy/get-recent-bp-stats 7))
         (diff (and this-week last-week (- this-week last-week))))
    (if this-week
        (message "📎주간 BP 리포트: 이번주 %.1f %s"
                 this-week
                 (if last-week
                     (format "(지난주 %.1f 대비 %+.1f %s)"
                             last-week diff (if (<= diff 0) "▼ 개선!" "▲ 주의"))
                   "(지난주 데이터 없음)"))
      (message "No BP data found."))))


(defun hy/org-capture-finalize-bp ()
  "Handle post-finalize actions for blood pressure capture (key: 'b')."
  (when (equal (org-capture-get :key) "b")
    (let ((today-str (format-time-string "%Y-%m-%d")))
      (with-current-buffer (find-file-noselect (expand-file-name hy/f-health))
        (save-excursion
          (goto-char (point-min))
          (when (re-search-forward "^\\*+ .*혈압 측정" nil t)
            ;; LAST_REPEAT 날짜가 오늘이면 이미 처리된 것 → 스킵
            (let ((last-repeat (org-entry-get (point) "LAST_REPEAT")))
              (unless (and last-repeat
                           (string-match today-str last-repeat))
                (org-todo "DONE")
                (save-buffer)))))))

    (run-with-timer 0.5 nil #'hy/bp-report)))


;;; ###autoload
(defun hy/show-bp-stats-by-tag ()
  "Generate BP report aggregated by Time/Status patterns."
  (interactive)
  (let ((stats-hash  (make-hash-table :test 'equal))
        (time-order  '("새벽" "오전" "점심" "오후" "저녁" "밤"))
        (total       (list 0.0 0.0 0.0 0))
        stats-list)
    (with-current-buffer (find-file-noselect (expand-file-name hy/f-health))
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward
                "| +\\([0-9.]+\\) | +\\([0-9.]+\\) | +\\([0-9.]+\\) | .*? \\([^ \t\n|/]+\\)/\\([^ \t\n| ]+\\)"
                nil t)
          (let* ((sys (string-to-number (match-string 1)))
                 (dia (string-to-number (match-string 2)))
                 (pul (string-to-number (match-string 3)))
                 (tag (concat (match-string 4) "/" (match-string 5)))
                 (cur (gethash tag stats-hash '(0.0 0.0 0.0 0))))
            (puthash tag (list (+ (nth 0 cur) sys) (+ (nth 1 cur) dia)
                               (+ (nth 2 cur) pul) (1+ (nth 3 cur))) stats-hash)
            (setq total (list (+ (nth 0 total) sys) (+ (nth 1 total) dia)
                              (+ (nth 2 total) pul) (1+ (nth 3 total))))))))

    (maphash (lambda (k v) (push (cons k v) stats-list)) stats-hash)
    (setq stats-list
          (sort stats-list
                (lambda (a b)
                  (let ((ia (cl-position (car (split-string (car a) "/")) time-order :test #'equal))
                        (ib (cl-position (car (split-string (car b) "/")) time-order :test #'equal)))
                    (if (and ia ib (not (= ia ib))) (< ia ib) (string< (car a) (car b)))))))

    (with-current-buffer (get-buffer-create "*Blood Pressure Stats*")
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "=== 통합 혈압 분석 리포트 ===\n")
        (insert (format "분석 일시: %s\n\n" (format-time-string "%Y-%m-%d %H:%M")))
        (insert (format "%-22s | %-8s | %-8s | %-5s\n" "상태 (시간대/상태)" "수축기" "이완기" "횟수"))
        (insert (make-string 62 ?-) "\n")
        (dolist (entry stats-list)
          (let* ((tag (car entry)) (d (cdr entry)) (n (nth 3 d)))
            (insert (format "%-22s | %-8.1f | %-8.1f | %-5d\n"
                            tag (/ (nth 0 d) (float n)) (/ (nth 1 d) (float n)) n))))
        (let ((n (nth 3 total)))
          (when (> n 0)
            (insert (make-string 62 ?-) "\n")
            (insert (format "전체 평균               | %-8.1f | %-8.1f | %-8.1f (총횟수 %d)\n"
                            (/ (nth 0 total) n) (/ (nth 1 total) n) (/ (nth 2 total) n) n))))
        (special-mode)
        (goto-char (point-min)))
      (pop-to-buffer (current-buffer)))))


;; ======================================
;;; 4. Main Org Configuration
;; ======================================
(use-package org
  :ensure nil
  :mode ("\\.org\\'" . org-mode)
  :hook (org-mode . (lambda () (text-scale-increase 1)))
  :bind (("C-c a" . org-agenda)
         ("C-c c" . org-capture)
         :map org-mode-map
         ("C-M-y"     . hy/paste-with-parentheses)
         ("M-,"       . org-insert-structure-template)
         ("C-,"       . hy/org-wrap-with-symbol-smart)
	 ("C-c C-l"   . hy/org-insert-link-dwim)
         ("C-c C-x d" . hy/org-insert-drawer-custom)
         ("C-c C-x i" . hy/org-insert-custom-prefix-to-blocks)
	 ("C-c C-x C-f" . hy/pair-pairs-wrap))        ;org-emphasize
  :custom
  (org-agenda-files                    (list hy/f-tasks hy/f-daily hy/f-health))
  (org-startup-indented                t)
  (org-startup-folded                  t)
  (org-adapt-indentation               nil)
  (org-edit-src-content-indentation    0)
  (org-image-actual-width              400)
  (org-startup-with-drawer             t)
  (org-log-into-drawer                 t)
  (org-log-repeat                      'time)
  (org-log-done                        'time)
  (org-todo-keywords                   '((sequence "TODO" "HOLD" "DONE")))
  (org-structure-template-alist
   '(("b" . "ltxBox")   ("c" . "center")  ("C" . "comment") ("e" . "src emacs-lisp") ("m" . "myquote")
     ("q" . "quote")    ("r" . "ltxRight") ("s" . "src")    ("v" . "verse")          ("x" . "example")))
  (org-export-with-smart-quotes        t)
  (org-export-with-special-strings     t)
  (org-export-with-sub-superscripts    '{})
  (org-fontify-done-headline           t)
  (org-fontify-quote-and-verse-blocks  t)
  (org-agenda-format-date              "%Y-%m-%d (%a)")
  (org-agenda-current-time-string      "← now ─────────")
  (org-agenda-restore-windows-after-quit t)
  (org-agenda-window-setup             'current-window)
  (org-agenda-inhibit-startup          t)
  (org-agenda-use-tag-inheritance      nil)
  (org-agenda-skip-function-global     '(org-agenda-skip-entry-if 'todo 'done))
  (org-habit-preceding-days            7)
  (org-habit-following-days            1)
  (org-habit-show-habits-only-for-today t)
  :config
  ;; (require 'org-tempo)
  (add-to-list 'org-modules 'org-habit)
  (add-hook 'org-capture-after-finalize-hook #'hy/org-capture-finalize-bp)
  
  (defun hy/org-capture-add-timestamp ()
    "Automatically appends the recording date when saving Daily, Tasks, or Reading items."
    (let ((key (plist-get org-capture-plist :key)))
      (when (member key '("d" "t" "r"))
        (save-excursion
          (goto-char (point-max))
          (unless (bolp) (insert "\n"))
          (insert "기록일: " (format-time-string "[%Y-%m-%d %a %H:%M]"))))))
  (add-hook 'org-capture-prepare-finalize-hook #'hy/org-capture-add-timestamp)

  (setq org-capture-templates
        `(("d" "Daily" entry (file+datetree ,hy/f-daily)
	   "* %?") ;; :empty-lines-after

          ("t" "Tasks" entry (file ,hy/f-tasks)
	   "* TODO %?") ;; :empty-lines-after

          ("b" "Blood Pressure" table-line (file+headline ,hy/f-health "혈압 데이터")
           ,(concat "| %U | %^{수축기} | %^{이완기} | %^{맥박} | %(hy/Bdays)"
                    "%^{상태|일반|기상직후|복용전|식후|운동후} "
                    "%(let ((s (hy/get-bp-stats))) (if s (format \" (Avg:%d)\" (truncate (car s))) \"\")) "
                    "%^{메모} |")
           :prepend t :immediate-finish t)

          ("h" "Habit: 혈압" entry (file+headline ,hy/f-health "습관 관리")
           "* TODO 혈압 측정\nSCHEDULED: %t\n:PROPERTIES:\n:STYLE: habit\n:END:" :immediate-finish t)

          ("r" "Reading" entry (file ,hy/f-read)
	   "* %?" :unnarrowed t) ;; :empty-lines-after

          ("m" "경조사" table-line (file ,hy/f-money)
           ,(format "| %%^{구분} | %%^{일자|%s} | %%^{이름} | %%^{연락처} | %%^{관계} | %%^{종류} | %%^{금액} | %%^{메모} |"
                    (format-time-string "%Y-%m-%d"))
           :prepend nil))))


;; ======================================
;;; 5. External Packages
;; ======================================
(use-package org-superstar
  :ensure nil
  :hook (org-mode . org-superstar-mode)
  :config (setq org-superstar-headline-bullets-list '("◉" "○" "●" "○" "▶" "▷" "►")))


(use-package org-appear
  :ensure t
  :hook (org-mode . org-appear-mode)
  :config
  (setq org-hide-emphasis-markers  t
        org-appear-autoemphasis    t
        org-appear-autolinks       t
        org-appear-autosubmarkers  t
        org-appear-delay           0.2))


(use-package ox-latex
  :ensure nil
  :after org
  :custom
  (org-latex-compiler      "xelatex")
  (org-latex-title-command "\\maketitle\\newpage")
  (org-latex-toc-command   "\\tableofcontents\\newpage")
  (org-latex-pdf-process
   '("latexmk -pdflatex='xelatex -shell-escape -interaction=nonstopmode' -pdf -f %f"))
  :config
  (add-to-list 'org-export-options-alist '(:quote-style "QUOTE_STYLE" nil nil t))
  (add-to-list 'org-export-filter-quote-block-functions #'hy/org-latex-filter-blocks)
  (add-to-list 'org-export-filter-verse-block-functions #'hy/org-latex-filter-blocks))


(use-package calendar
  :ensure nil
  :custom
  (calendar-week-start-day  0)
  (calendar-date-style      'iso)
  (calendar-month-name-array
   ["1월" "2월" "3월" "4월" "5월" "6월"
    "7월" "8월" "9월" "10월" "11월" "12월"]))


(use-package valign
  ;; :custom
  ;; (valign-fancy-bar t)           ;"May slow down with large tables"
  :hook (org-mode . valign-mode))


;; ======================================
;;; denote
;; ======================================
(use-package denote
  :defer t
  :bind (("C-c n n" . denote)
         ("C-c n i" . denote-link)
         ("C-c n b" . denote-show-backlinks-buffer)
         ("C-c n r" . denote-rename-file))
  :config
  (setq denote-directory (dropbox/dir "org/denote")
        denote-file-type nil)
  (unless (file-exists-p denote-directory)
    (make-directory denote-directory t))
  (denote-menu-bar-mode -1))


(provide 'hy-org-custom)
;;; hy-org-custom.el ends here
