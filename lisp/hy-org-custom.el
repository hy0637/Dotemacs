;;; hy-org-custom.el --- Optimized Org-mode configuration -*- lexical-binding: t; -*-
;;; 20260703 수정본 (단축키 & Autoload 최적화)
;;; Commentary:
;; Personal Org-mode configuration with centralized file paths and health tracking.

;;; Code:
;;

;; ======================================
;;; 0. Load Path & Sub-modules Extension
;; ======================================
(defvar hy/lisp-path)

(when (boundp 'hy/lisp-path)
  (add-to-list 'load-path hy/lisp-path))

;; 외부 헬스 모듈 자동 로드 설정 (정상)
(autoload 'hy/org-capture-finalize-bp "hy-org-health" "BP capture finalize hook." t)
(autoload 'hy/show-bp-stats-by-tag "hy-org-health" "Show BP stats report." t)
(autoload 'hy/get-bp-stats "hy-org-health" "Get BP stats." nil)
(autoload 'hy/bp-report "hy-org-health" "Show BP report." t)
(autoload 'hy/Bdays "hy-org-health" "BP days tag." nil)


;; ======================================
;;; 1. Variables & File Paths
;; ======================================
(defun hy/get-dropbox-dir (subpath)
  "Get absolute path inside Dropbox directory."
  (if (fboundp 'dropbox/dir)
      (dropbox/dir subpath)
    (expand-file-name (concat "~/Dropbox/Docs/" subpath))))


(defvar hy/org-person-dir (hy/get-dropbox-dir "Person/")
  "Directory for personal org files.")


(defvar hy/f-daily   (expand-file-name "Daily.org"    hy/org-person-dir))
(defvar hy/f-tasks   (expand-file-name "Tasks.org"    hy/org-person-dir))
(defvar hy/f-health  (expand-file-name "Health.org"   hy/org-person-dir))
(defvar hy/f-read    (expand-file-name "cReading.org" hy/org-person-dir))
(defvar hy/f-money   (expand-file-name "aMoney.org"   hy/org-person-dir))


(defvar hy/pngpaste-bin
  (or (executable-find "pngpaste") "/opt/homebrew/bin/pngpaste")
  "pngpaste executable path.")


(defvar hy/bp-start-date (encode-time '(0 0 0 3 4 2026 nil -1 nil)) "BP💊 start date (2026-04-03).")


;; ======================================
;;; 2. Helper Functions
;; ======================================
(defvar hy/org-last-inserted-image nil
  "Last image file inserted by hy/org-insert-image.")


;;;###autoload
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


;;;###autoload
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


;; (defun hy/org-insert-custom-prefix-to-blocks (beg end prefix)
;;   "선택 영역 내, 빈 줄이 아닌 줄 시작점에 사용자가 입력한 문자열(prefix) 삽입."
;;   (interactive "r\ns삽입할 문구를 입력하세요: ")
;;   (save-excursion
;;     (save-restriction
;;       (narrow-to-region beg end)
;;       (goto-char (point-min))
;;       (while (not (eobp))
;;         (when (and (not (looking-at "^\\s-*$"))
;;                    (not (looking-at "^[ \t]*#\\+")))
;;           (back-to-indentation)
;;           (insert prefix))
;;         (forward-line 1))))
;;   ;; (deactivate-mark)
;;   (when (use-region-p)
;;     (setq deactivate-mark nil))
;;   (message "동작 완료!" prefix))


(defun hy/org-insert-link-dwim ()
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


(defun hy/org--search-visible-line (backward)
  "Search for the nearest visible non-blank line start."
  (let ((regexp "^[ \t]*\\([^ \t\n]\\)")
        found)
    (while (and (not found)
                (if backward
                    (re-search-backward regexp nil t)
                  (re-search-forward regexp nil t)))
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
(defun hy/org-goto-paragraph-start (&optional arg)
  "Move point to the next (or previous with negative ARG) visible paragraph/item/heading."
  (interactive "p")
  (let ((backward (< (or arg 1) 0))
        (steps (abs (or arg 1))))
    (save-match-data
      (dotimes (_ steps)
        (if backward
            (beginning-of-line)
          (end-of-line))
        (when (hy/org--search-visible-line backward)
          (hy/org--land))))))


;;;###autoload
(defun hy/org-toggle-emphasis-markers ()
  "Toggle visibility of org emphasis markers."
  (interactive)
  (setq org-hide-emphasis-markers (not org-hide-emphasis-markers))
  (font-lock-flush)
  (message "강조 기호 %s" (if org-hide-emphasis-markers "숨김" "표시")))


;;;###autoload
(defun hy/org-mark-current-body-only ()
  "현재 Org 헤딩의 제목 줄을 제외한 본문 내용만 (다음 헤딩 직전까지) 블록 선택."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Org-mode에서만 사용할 수 있는 기능입니다."))
  (let (beg end)
    (save-excursion
      ;; 1. 현재 헤딩의 시작점으로 이동 후 다음 줄을 시작점(beg)으로 지정
      (org-back-to-heading t)
      (forward-line 1)
      (setq beg (point))
      
      ;; 2. 다음 헤딩 위치를 찾음 (없으면 파일 끝)
      (if (outline-next-heading)
          (setq end (point))
        (setq end (point-max)))
      
      ;; 3. 다음 헤딩 바로 윗줄의 빈 줄이나 줄바꿈을 고려해 본문 끝 글자 위치로 보정
      (goto-char end)
      (when (bolp)
        (backward-char 1))
      (setq end (point)))
    
    ;; 4. 최종 영역 선택 활성화
    (push-mark beg nil t)
    (goto-char end)
    (activate-mark)
    (message "현재 헤딩의 본문 영역 전체가 선택되었습니다.")))


;; ======================================
;;; 3. Main Org Configuration
;; ======================================
(use-package org
  :ensure nil
  :mode ("\\.org\\'" . org-mode)
  :hook (org-mode . (lambda ()
		      (text-scale-increase 1)))
  :bind (("C-c a" . org-agenda)
         ("C-c c" . org-capture)
         :map org-mode-map
         ("C-M-y"     . hy/paste-with-parentheses)
         ("C-M-'"     . hy/normalize-quotes)
         ("M-n"       . (lambda () (interactive) (hy/org-goto-paragraph-start 1)))
         ("M-p"       . (lambda () (interactive) (hy/org-goto-paragraph-start -1)))
         ("M-,"       . org-insert-structure-template)
         ("C-c C-l"   . hy/org-insert-link-dwim)
         ("C-c C-x d" . hy/org-insert-drawer-custom)
         ("C-c C-x C-f" . hy/pair-wrap)
         ("C-c C-x m"   . hy/org-mark-current-body-only))
  
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
  (org-fontify-whole-heading-line      t)
  (org-table-shading-column            nil)
  (org-agenda-format-date              "%Y-%m-%d (%a)")
  (org-agenda-current-time-string      "← now ─────────")
  (org-agenda-restore-windows-after-quit t)
  (org-agenda-window-setup             'current-window)
  (org-agenda-inhibit-startup          t)
  (org-agenda-use-tag-inheritance      nil)
  (org-agenda-skip-function-global  (lambda () (org-agenda-skip-entry-if 'todo 'done)))
  (org-habit-preceding-days            7)
  (org-habit-following-days            1)
  (org-habit-show-habits-only-for-today t)
  :config
  (require 'hy-org-health nil  t)
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
        `(("d" "Daily" entry (file+datetree ,hy/f-daily) "* %?")
          ("t" "Tasks" entry (file ,hy/f-tasks) "* TODO %?")
          ("b" "Blood Pressure" table-line (file+headline ,hy/f-health "혈압 데이터")
            ,(concat "| %U | %^{수축기} | %^{이완기} | %^{맥박} | %(hy/Bdays)"
                    "%^{상태|일반|기상직후|복용전|식후|운동후} "
                    "%(hy/org-capture-bp-avg) "
                    "%^{메모} |")
            :prepend t :immediate-finish t)
          ("f" "Finance" table-line
           (file ,(expand-file-name "Finance.org" hy/org-person-dir))
           "| %(format-time-string \"%Y-%m-%d\") | %^{항목} | %^{분류|식비|교통|주거|기타|경조사} | %^{수입|0} | %^{지출|0} | %^{비고} |"
           :prepend nil :immediate-finish t)
          ("r" "Reading" entry (file ,hy/f-read) "* %?" :unnarrowed t)
          ("m" "aMoney" table-line (file ,hy/f-money)
           "| %^{구분} | %^{일자} | %^{이름} | %^{연락처} | %^{관계} | %^{종류} | %^{금액} | %^{메모} |"
           :prepend nil))))


;; ======================================
;;; 4. External Packages
;; ======================================
(use-package org-modern
  :ensure t
  :hook (org-mode . org-modern-mode)
  :custom
  (org-modern-star 'replace)
  (org-modern-replace-stars '("◉" "○" "●" "○" "▶" "▷"))
  (org-modern-cycle-stars nil)  ; 6단계 넘으면 마지막 문자(▷) 반복
  (org-modern-todo nil)         ; TODO 배지 비활성화
  (org-modern-tag nil)          ; 태그 박스 비활성화
  (org-modern-keyword nil)      ; 메타데이터 순정 유지
  (org-modern-timestamp nil))


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


(provide 'hy-org-custom)
;;; hy-org-custom.el ends here
