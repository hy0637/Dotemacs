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
  :bind (("C-." . embark-act)         ;; 가장 기본적인 '행동'
         ;; ("M-." . embark-dwim)        ;; 알아서 가장 적절한 '행동' 수행
         ("C-h B" . embark-bindings)) ;; 현재 모드에서 가능한 모든 키 바인딩 확인
  :init
  (setq prefix-help-command #'embark-prefix-help-command))         ;; 미니버퍼 내에서 도움말 가능하도록


(use-package embark-consult
  :ensure t
  :after (embark consult)
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))


;; =======================================
;;; pair-pair-wrap
;; =======================================
;;inspire https://protesilaos.com
(defcustom hy/pair-pairs
  '((?* :description "Bold"           :pair ?*)
    (?/ :description "Italic"         :pair ?/)
    (?= :description "Verbatim"       :pair ?=)
    (?~ :description "Code"           :pair ?~)
    (?+ :description "Strike"         :pair ?+)
    (?_ :description "Under Line"     :pair ?_)
    (?\" :description "Double Quotes" :pair ?\")
    (?\' :description "Single Quotes" :pair ?\')
    (?\( :description " () "          :pair (?\( . ?\)))
    (?\[ :description " [] "          :pair (?\[ . ?\]))
    (?{  :description " {} "          :pair (?{ . ?}))
    (?,  :description " <> "          :pair (?< . ?>))
    (?<  :description " 「」  "          :pair ("「" . "」"))
    (?>  :description " 『』  "          :pair ("『" . "』"))
    (?M  :description " 《》 "          :pair ("《" . "》")))
  "List of Org-mode emphasis markers and special bracket pairs."
  :group 'editing
  :type '(alist :key-type character :value-type (plist)))

(defun hy/pair-pairs-wrap (char &optional _target)
  "Enclose the active region or the word at point with a pair of CHARs.
Detects existing open/close delimiters in the region and replaces or inserts accordingly."
  (interactive "c기호 입력 (*, /, =, (, <...): ")
  (let* ((entry (assoc char hy/pair-pairs))
         (pair-data (plist-get (cdr entry) :pair))
         (open      (if (consp pair-data) (car pair-data) pair-data))
         (close     (if (consp pair-data) (cdr pair-data) pair-data))
         (open-str  (if (characterp open)  (char-to-string open)  open))
         (close-str (if (characterp close) (char-to-string close) close)))
    (if (not pair-data)
        (message "Undefined symbol: %c" char)
      (if (not (use-region-p))
          ;; region 없음: word at point 감싸기
          (let* ((bounds (or (bounds-of-thing-at-point 'symbol)
                             (cons (point) (point))))
                 (start (car bounds))
                 (end   (cdr bounds)))
            (save-excursion
              (goto-char end)   (insert close-str)
              (goto-char start) (insert open-str)))
        ;; region 있음
        (let* ((rbeg (region-beginning))
               (rend (region-end))
               (all-pairs
                (apply #'append
                       (mapcar (lambda (e)
                                 (let* ((key (car e))
                                        (pd  (plist-get (cdr e) :pair)))
                                   (when (consp pd)
                                     (let* ((os  (if (characterp (car pd))
                                                     (char-to-string (car pd))
                                                   (car pd)))
                                            (cs  (if (characterp (cdr pd))
                                                     (char-to-string (cdr pd))
                                                   (cdr pd)))
                                            (key-str (char-to-string key)))
                                       (list (cons os       cs)
                                             (cons key-str  cs)
                                             (cons os       key-str)
                                             (cons key-str  key-str))))))
                               hy/pair-pairs)))
               (existing-open
                (cl-some (lambda (p)
                           (let ((os (car p)))
                             (when (string= os (buffer-substring-no-properties
                                                rbeg
                                                (min (+ rbeg (length os)) rend)))
                               os)))
                         all-pairs))
               (existing-close
                (cl-some (lambda (p)
                           (let ((cs (cdr p)))
                             (when (string= cs (buffer-substring-no-properties
                                                (max (- rend (length cs)) rbeg)
                                                rend))
                               cs)))
                         all-pairs))
               (open-len  (length (or existing-open  "")))
               (close-len (length (or existing-close ""))))
          (save-excursion
            ;; 뒤쪽 먼저
            (if existing-close
                (progn (goto-char (- rend close-len))
                       (delete-char close-len)
                       (insert close-str))
              (goto-char rend)
              (insert close-str))
            ;; 앞쪽
            (if existing-open
                (progn (goto-char rbeg)
                       (delete-char open-len)
                       (insert open-str))
              (goto-char rbeg)
              (insert open-str)))
          (message "'%s' 완료" (plist-get (cdr entry) :description)))))))

(with-eval-after-load 'embark
  (dolist (map (list embark-symbol-map
                     embark-region-map
                     embark-general-map))
    (define-key map (kbd "w") #'hy/pair-pairs-wrap)))


;; =======================================
;;; Hunspell 설정
;; =======================================
;; (defun hy-korean-spell-check ()
;;   "Set hunspell as the default spell checker for Korean"
;;   (interactive)
;;   (require 'ispell) ;; 함수 실행 시 패키지 로드
;;   (setq ispell-local-dictionary "ko_KR")
;;   (flyspell-mode 1)
;;   (message "Korean spell check enable"))

;; (use-package ispell
;;   :if hy-macOS-p
;;   :defer t
;;   :config
;;   (setq ispell-program-name "hunspell")
;;   (setq ispell-local-dictionary-alist
;;         '(("ko_KR" "[가-힣]" "[^가-힣]" "[-']" nil ("-d" "ko_KR") nil utf-8)))
;;   (setq flyspell-delay 0.5)
;;   (setq flyspell-issue-message-flag nil)
;;   (setq flyspell-use-meta-tab nil))


;; =======================================
;;; completion-preview
;; =======================================
(use-package completion-preview
  :ensure nil
  :init (global-completion-preview-mode)
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
	       ("Wfig" "#+ATTR_LATEX: :float wrap :width 0.3\\textwidth :placement {r}{0.3\\textwidth}\n[[file:./img/PATH]]\n")
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
        (let ((pairs '(("->"  . "→") ("<-"  . "←")
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
