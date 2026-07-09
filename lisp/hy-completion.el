;;; hy-completion.el --- configuration -*- lexical-binding: t; -*-

;;; CODE;


;; ======================================
;;; vertico
;; ======================================
(use-package vertico
  :init (vertico-mode)
  :custom
  (vertico-resize nil)
  (vertico-cycle t)
  (vertico-count 15))


;; (use-package vertico-directory
;;   :ensure nil
;;   :after vertico
;;   :bind (:map vertico-map
;;          ("RET"   . vertico-directory-enter)
;;          ("DEL"   . vertico-directory-delete-char)
;;          ("M-DEL" . vertico-directory-delete-word)
;;          ("C-w"   . vertico-directory-delete-word))
;;   :hook (rfn-eshadow-update-overlay . vertico-directory-tidy))

;; ======================================
;;; marginalia
;; ======================================
(use-package marginalia
  :init (marginalia-mode)
  :custom
  (marginalia-align 'right)
  (marginalia-align-offset 0))


;; ======================================
;;; orderless
;; ======================================
(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))


;; ======================================
;;; consult
;; ======================================
(use-package consult
  :ensure t
  :bind (("C-x b" . consult-buffer)
         ("C-x C-r" . consult-recent-file)
         ("C-c B" . consult-bookmark)
         ("M-y"   . consult-yank-pop)
	 ("M-s f" . hy/fd-filename-search)
         ("M-s g" . consult-ripgrep)
         ("M-s l" . consult-line)
         ("M-s m" . consult-imenu)
         ("M-s o" . consult-outline)
         ("M-g M-g" . consult-goto-line))
  :config
  (setq consult-preview-key '(:debounce 0.5 any)))


;; =======================================
;;; wgrep
;; =======================================
(use-package wgrep
  :ensure nil
  :config
  (setq wgrep-auto-save-buffer t)
  (setq wgrep-change-readonly-file t))


;; =======================================
;;; embark
;; =======================================
(use-package embark
  :ensure t
  :bind (("C-." . embark-act)               ; 가장 기본적인 '행동'
         ;; ("C-h B" . embark-bindings)        ; 현재 모드에서 가능한 모든 키 바인딩 확인
	 :map help-map
         ("b" . embark-bindings)            ; C-h b: 버퍼 전체 단축키를 Vertico로 검색
         ("B" . embark-bindings-at-point)   ; C-h B: 현재 커서 위치의 단축키만 추출
         ("M" . embark-bindings-in-keymap)) ; C-h M: 특정 키맵 내부 단축키만 조준 검색
  :init
  (setq prefix-help-command #'embark-prefix-help-command))         ;; 미니버퍼 내에서 도움말 가능하도록


(use-package embark-consult
  :ensure t
  :after (embark consult)
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))


;; =======================================
;;; Hanspell
;; =======================================
(defun hy/org-korean-spellcheck-region (beg end)
  "선택한 영역의 맞춤법 교정 리포트를 별도 버퍼에 띄워 검토합니다.
교정할 내용이 없으면 메시지만 표시하고 종료합니다."
  ;; brew install node
  ;; npm install -g hanspell
  (interactive "r")
  (let* ((hanspell-path "/opt/homebrew/bin/hanspell-cli")
         (cmd (if (executable-find "hanspell-cli") "hanspell-cli" hanspell-path))
         (buf-name "*Korean Spell Check*")
         (text (buffer-substring-no-properties beg end))
         raw-output)
    (if (not (file-executable-p hanspell-path))
        (user-error "터미널에서 'npm install -g hanspell'이 정상 설치되지 않았습니다.")
      
      ;; 1. hanspell 결과 가져오기
      (setq raw-output (shell-command-to-string 
                        (format "echo %s | %s -n" (shell-quote-argument text) cmd)))
      
      ;; [핵심 추가] 결과물에 교정 기호(->)가 없거나 비어있다면 오타가 없는 것임
      (if (or (string-empty-p (string-trim raw-output))
              (not (string-match-p "->" raw-output)))
          (message "✨ 맞춤법이 완벽합니다! 교정할 내용이 없습니다.")
        
        ;; 2. 오타가 있을 때만 가독성 개선 및 팝업창 생성
        (setq raw-output (replace-regexp-in-string "오류입니다\\." "오류입니다. 🚨\n" raw-output))
        (setq raw-output (replace-regexp-in-string "추천입니다\\." "추천입니다. 💡\n" raw-output))
        
        (with-current-buffer (get-buffer-create buf-name)
          (read-only-mode -1)
          (erase-buffer)
          (org-mode)
          (insert raw-output)
          (goto-char (point-min))
          (read-only-mode 1)
          
          (local-set-key (kbd "q") (lambda () 
                                     (interactive)
                                     (let ((win (get-buffer-window (current-buffer))))
                                       (when win (delete-window win))
                                       (kill-buffer (current-buffer))))))
        
        (display-buffer buf-name)
        (message "맞춤법 검사 완료! 검토 후 'q'를 눌러 닫으세요.")))))


;; =======================================
;;; completion-preview
;; =======================================
(use-package completion-preview
  :ensure nil
  :init (global-completion-preview-mode)
  :hook (emacs-lisp-mode . (lambda () (completion-preview-mode -1)))
  :config
  (push 'org-self-insert-command completion-preview-commands))


;; =======================================
;;; corfu
;; =======================================
(use-package corfu
  :ensure t
  :hook (emacs-lisp-mode . corfu-mode)
  :bind (:map corfu-map
         ("TAB" . corfu-insert)
         ("RET" . nil))
  :config
  (setq corfu-auto t)
  (setq corfu-auto-delay 0.3)
  (setq corfu-auto-prefix 2))


;; =======================================
;;; abbrev
;; =======================================
(use-package abbrev
  :ensure nil
  :hook (org-mode . abbrev-mode)
  :custom
  (save-abbrevs nil)
  :config
  (with-eval-after-load 'org
    ;; 기본 설정
    (abbrev-table-put org-mode-abbrev-table :case-fixed t)
    ;; 특수기호
    (dolist (pair
             '(("lS"  "―") ("lT"  "……")
               ("lG"  "「") ("rG"  "」")
               ("llG" "『") ("rrG" "』")
               ("cD"  "·")))
      (define-abbrev org-mode-abbrev-table
        (car pair) (cadr pair)))
    ;; Org 템플릿 세트
    (dolist (pair
             '(("Dsc"     "#+DESCRIPTION: ")
               ("Title"   "#+TITLE: ")
               ("Author"  "#+AUTHOR: ")
               ("Keyword" "#+KEYWORDS: ")
               ("Setfile" "#+SETUPFILE: setLTH/Header.org")
               ("Center"  "#+BEGIN_CENTER\n· · ·\n#+END_CENTER")
               ("Nonum"   ":PROPERTIES:\n:UNNUMBERED: t\n:END:")
               ("Opt"     "#+OPTIONS: toc:2 num:2 d:nil")
               ("Qsty"    "#+QUOTE_STYLE:")
               ("Grayq"   "#+ATTR_LATEX: :environment grayquote")
               ("Doimg"   "#+ATTR_LATEX: :width 0.7\\textwidth \n")
               ("Doimgc"  "#+ATTR_LATEX: :width 0.7\\textwidth\n#+CAPTION: \n")
               ("Right"   "#+BEGIN_EXPORT latex\n\\begin{flushright}\n\n\\end{flushright}\n#+END_EXPORT")
	       ("Wfig"    "#+ATTR_LATEX: :float wrap :width 0.3\\textwidth :placement {r}{0.3\\textwidth}\n[[file:./img/PATH]]\n")
               ("Bskip"   "#+LATEX: \\bigskip")
               ;; ("Mskip"   "#+LATEX: \\medskip")
               ("Nskip"   "#+LATEX: \\vspace{\\baselineskip}")))
      (define-abbrev org-mode-abbrev-table
        (car pair) (cadr pair)))
    ;; Notoc (section에서 제외)
    (define-abbrev
      org-mode-abbrev-table
      "Notoc"
      "#+LATEX: \\addcontentsline{toc}{section}{}"
      (lambda () (backward-char 1)))
    
    ;; Cover (titlepage 삽입용)
    (define-abbrev
      org-mode-abbrev-table
      "Cover"
      "#+begin_src emacs-lisp :exports results :results none :eval export
(make-variable-buffer-local 'org-latex-title-command)
(setq org-latex-title-command
      (concat
       \"\\\\begin{titlepage}\n\"
       \"\\\\includegraphics[width=14.7cm]{./img/PATH}\n\"
       \"\\\\end{titlepage}\n\"))
#+end_src")

    ;; 코딩식 자동 즉시 변환
    (defun hy/org-auto-symbol-replace ()
      (when (and (not (org-in-src-block-p))
                 (not (org-at-table-p))
                 (not (org-in-verbatim-emphasis)))
        (let ((pairs '(("->"  . "→") ("<-"  . "←") ("+="  . "·")
                       ("=>"  . "⇒") ("<="  . "⇐")
                       ("<_"  . "≤") (">_"  . "≥")
                       ("<<"  . "《") (">>"  . "》")
                       ("~="  . "≈") ("+-"  . "±"))))
          (catch 'done
            (dolist (pair pairs)
              (let* ((key (car pair))
                     (val (cdr pair))
                     (len (length key)))
                (when (and (>= (point) len)
                           (string=
                            key
                            (buffer-substring-no-properties
                             (- (point) len) (point))))
                  (delete-region (- (point) len) (point))
                  (insert val)
                  (throw 'done nil))))))))
    (add-hook 'org-mode-hook
              (lambda ()
                (add-hook 'post-self-insert-hook
                          #'hy/org-auto-symbol-replace
                          nil t)))))

;; end here
(provide 'hy-completion)
