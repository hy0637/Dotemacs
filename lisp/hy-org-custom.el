;;; hy-org-custom.el --- Optimized Org-mode configuration -*- lexical-binding: t; -*-
;;; 20260625
;;; Commentary:
;; Personal Org-mode configuration with centralized file paths and health tracking.

;;; Code:
;;

;; ======================================
;;; 0. Load Path & Sub-modules Extension
;; ======================================
(defvar hy/lisp-path)  ;; init.el에 정의된 전역 변수를 재사용 위한 선언 (컴파일 경고 방지)

(when (boundp 'hy/lisp-path)
  (add-to-list 'load-path hy/lisp-path))

;; 해당 함수들이 호출될 때만 'hy-org-health 파일 읽기(로딩 지연)
(autoload 'hy/org-capture-finalize-bp "hy-org-health" "BP capture finalize hook." t)
(autoload 'hy/bp-report "hy-org-health" "Show BP report." t)
(autoload 'hy/show-bp-stats-by-tag "hy-org-health" "Show BP stats report." t)
(autoload 'hy/Bdays "hy-org-health" "BP days tag." nil)
(autoload 'hy/get-bp-stats "hy-org-health" "Get BP stats." nil)

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
(defun hy/org-insert-custom-prefix-to-blocks (beg end prefix)
  "선택 영역 내, 빈 줄이 아닌 줄 시작점에 사용자가 입력한 문자열(prefix) 삽입."
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
  ;; https://github.com/hrs/dotfiles/blob/main/emacs/.config/emacs/configuration.org
  "Like `org-insert-link' but with personal dwim preferences."
  (interactive)
  (let* ((point-in-link (org-in-regexp org-link-any-re 1))
         (clipboard-url (when (and kill-ring
                                   (stringp (car kill-ring))
                                   (string-match-p "^https?://" (car kill-ring)))
                          (car kill-ring)))
         (region-content (when (region-active-p)
                           (buffer-substring-no-properties (region-beginning)
                                                           (region-end)))))
    (cond ((and region-content clipboard-url (not point-in-link))
           (delete-region (region-beginning) (region-end))
           (insert (org-make-link-string clipboard-url region-content))
           (message "%s" clipboard-url))
          ((and clipboard-url (not point-in-link))
           (let ((url-buf (url-retrieve-synchronously clipboard-url)))
             (insert (org-make-link-string
                      clipboard-url
                      (read-string "title: "
                                   (condition-case nil
                                       (unwind-protect
                                           (with-current-buffer url-buf
                                             (let ((dom (condition-case nil
                                                            (libxml-parse-html-region (point-min) (point-max))
                                                          (error nil))))
                                               (if dom
                                                   (let ((title-node (car (dom-by-tag dom 'title))))
                                                     (if title-node
                                                         (string-trim (dom-text title-node))
                                                       "No Title"))
                                                 "No Title")))
                                         (kill-buffer url-buf))
                                     (error "No Title")))))))
          (t
           (call-interactively 'org-insert-link)))))


;;; org-goto-next-paragraph-start START

(defun hy/org--search-visible-line (backward)
  "Search for the nearest visible non-blank line start.
BACKWARD non-nil이면 역방향. 성공 시 match data를 남기고 t 반환."
  (let ((regexp "^[ \t]*\\([^ \t\n]\\)")
        found)
    (while (and (not found)
                (if backward
                    (re-search-backward regexp nil t)
                  (re-search-forward regexp nil t)))
      ;; 접힌(invisible) 영역 안의 매칭은 건너뜀
      (unless (invisible-p (match-beginning 1))
        (setq found t)))
    found))

(defun hy/org--land ()
  "매칭 지점으로 이동 후 리스트/헤딩에 맞게 안착."
  (goto-char (match-beginning 1))
  (cond
   ((org-at-item-p) (goto-char (org-in-item-p)))
   ((org-at-heading-p) (beginning-of-line))))

;;;###autoload
(defun hy/org-goto-next-paragraph-start ()
  "Move point to the next visible paragraph/item/heading."
  (interactive)
  (end-of-line)
  (save-match-data
    (when (hy/org--search-visible-line nil)
      (hy/org--land))))

;;;###autoload
(defun hy/org-goto-previous-paragraph-start ()
  "Move point to the previous visible paragraph/item/heading."
  (interactive)
  (beginning-of-line)
  (save-match-data
    (when (hy/org--search-visible-line t)
      (hy/org--land))))

;;; org-goto-next-paragraph-start END


;;;###autoload
(defun hy/org-toggle-emphasis-markers ()
  "Toggle visibility of org emphasis markers."
  (interactive)
  (setq org-hide-emphasis-markers (not org-hide-emphasis-markers))
  (font-lock-flush)
  (message "강조 기호 %s" (if org-hide-emphasis-markers "숨김" "표시")))


;; ======================================
;;; 3. Main Org Configuration
;; ======================================
(use-package org
  :ensure nil
  :mode ("\\.org\\'" . org-mode)
  :hook (org-mode . (lambda () (text-scale-increase 1)))
  :bind (("C-c a" . org-agenda)
         ("C-c c" . org-capture)
         :map org-mode-map
         ("C-M-y"     . hy/paste-with-parentheses)
         ("C-M-'"     . hy/normalize-quotes)
	 ("M-n"       . hy/org-goto-next-paragraph-start)
         ("M-p"       . hy/org-goto-previous-paragraph-start)
	 ("M-,"       . org-insert-structure-template)
	 ("C-c C-l"   . hy/org-insert-link-dwim)
         ("C-c C-x d" . hy/org-insert-drawer-custom)
         ("C-c C-x i" . hy/org-insert-custom-prefix-to-blocks)
	 ("C-c C-x C-f" . hy/pair-pairs-wrap))        ;alternative org-emphasize
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

	  ("f" "Finance" table-line
           (file ,(expand-file-name "Finance.org" hy/org-person-dir))
           "| %(format-time-string \"%Y-%m-%d\") | %^{항목} | %^{분류|식비|교통|주거|기타|경조사} | %^{수입|0} | %^{지출|0} | %^{비고} |"
           :prepend nil :immediate-finish t)

          ;; ("h" "Habit: 혈압" entry (file+headline ,hy/f-health "습관 관리")
          ;;  "* TODO 혈압 측정\nSCHEDULED: %t\n:PROPERTIES:\n:STYLE: habit\n:END:" :immediate-finish t)

          ("r" "Reading" entry (file ,hy/f-read)
	   "* %?" :unnarrowed t) ;; :empty-lines-after

          ("m" "aMoney" table-line (file ,hy/f-money)
           ,(format "| %%^{구분} | %%^{일자|%s} | %%^{이름} | %%^{연락처} | %%^{관계} | %%^{종류} | %%^{금액} | %%^{메모} |"
                    (format-time-string "%Y-%m-%d"))
           :prepend nil))))


;; ======================================
;;; 4. External Packages
;; ======================================
(use-package org-superstar
  :ensure t
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
  :ensure t
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
