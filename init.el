;;; -*- lexical-binding: t -*-
;;  emacs conf for macOS
;;  ver260616

;; CODE

;;
;; =======================================
;; Path helpers
;; =======================================
(defun emacs/dir (subdir)
  "Return the absolute path of SUBDIR relative to `user-emacs-directory'."
  (expand-file-name subdir user-emacs-directory))

(defun dropbox/dir (subdir)
  "Return the absolute path of SUBDIR relative to \"~/Dropbox/Docs/\"."
  (expand-file-name subdir "~/Dropbox/Docs/"))


;; =======================================
;; Global variables
;; =======================================
(defvar hy/lisp-path (emacs/dir "lisp/")
  "Path to the user's personal lisp directory.")

(defvar hy-macOS-p (eq system-type 'darwin))

(defvar hy-Macbook-p (string-prefix-p "MacBookAir" (system-name)))

(setq org-directory (dropbox/dir "org"))


;; =======================================
;;; Custom file
;; =======================================
(setq custom-file (emacs/dir "custom.el"))

(unless (file-exists-p custom-file)
  (write-region "" nil custom-file))
(load custom-file t t)


;; =======================================
;;; Package initialization
;; =======================================
(require 'package)

;; 저장소 목록 / 우선순위 설정
(setq package-archives
      '(("gnu-elpa" . "https://elpa.gnu.org/packages/")
        ("nongnu"   . "https://elpa.nongnu.org/nongnu/")
        ("melpa-stable" . "https://stable.melpa.org/packages/"))
      package-archive-priorities
      '(("nongnu"   . 20)
        ("gnu-elpa" . 10)
        ("melpa-stable" . 5)))

;; 패키지 초기화 / 최적화
(setq package-install-upgrade-built-in nil
      package-quickstart t
      use-package-always-ensure nil
      use-package-always-defer nil
      use-package-expand-minimally t)

 (package-initialize)


;; =======================================
;;; exec-path-from-shell
;; =======================================
;; (use-package exec-path-from-shell
;;   :defer 2
;;   :if hy-macOS-p
;;   :config
;;   (setq exec-path-from-shell-variables '("PATH" "MANPATH" "LIBRARY_PATH"))
;;   (exec-path-from-shell-initialize))


;; =======================================
;;; macOS PATH
;; =======================================
(when hy-macOS-p
  (let ((brew-bin "/opt/homebrew/bin")
        (tex-bin "/Library/TeX/texbin")
	(emacs-bin "/Applications/Emacs.app/Contents/MacOS/bin"))
    (dolist (path (list brew-bin tex-bin emacs-bin))
      (when (file-directory-p path)
        (add-to-list 'exec-path path)
        (setenv "PATH" (concat path ":" (getenv "PATH")))))
    
    ;; Dired ls 설정
    (let ((gls-prog (executable-find "gls")))
      (setq insert-directory-program (or gls-prog "ls")
            dired-use-ls-dired (if gls-prog t nil)))))


;; =======================================
;;; Native Compilation Settings 
;; =======================================
(when (and hy-macOS-p (fboundp 'native-comp-available-p) (native-comp-available-p))
  (let* (;; 순수 Elisp glob — 속도 부담 없음
         (gcc-bin (car (file-expand-wildcards "/opt/homebrew/bin/gcc-[0-9]*")))
         (gcc-lib-1 "/opt/homebrew/lib/gcc/current")
         (gcc-lib-2 (car (file-expand-wildcards
                          "/opt/homebrew/Cellar/gcc/*/lib/gcc/current/gcc/aarch64-apple-darwin*/[0-9]*")))
         ;; sdk는 변경 빈도 낮아 하드코딩 유지
         (sdk-lib "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib"))

    (when gcc-bin
      (setq native-comp-driver-path gcc-bin))

    (setenv "LIBRARY_PATH"
            (string-join
             (seq-uniq
              (seq-filter #'file-directory-p
                          (append
                           (split-string (or (getenv "LIBRARY_PATH") "") ":" t)
                           (list gcc-lib-1 gcc-lib-2 sdk-lib))))
             ":"))

    (setq native-comp-async-report-warnings-errors 'silent)))


;; =======================================
;;; Load custom packages
;; =======================================
(add-to-list 'load-path hy/lisp-path)

(require 'hy-completion)
(require 'hy-dired-custom)
(require 'hy-hangul)
(require 'hy-org-custom)
(require 'hy-useful-custom)
(require 'hy-pairs)
(require 'hy-app)
(require 'hy-search)
(require 'hy-todays-pop)
(require 'hy-keys)

(autoload 'hy/radio-play "hy-radio-direct" "라디오 실행 함수" t)

;; =======================================
;;; MacOS keyboard
;; =======================================
(when hy-macOS-p
  ;; [왼쪽] Opt(Super) / Cmd(Meta)
  (setq ns-option-modifier 'super)
  (setq ns-command-modifier 'meta)
  (setq ns-right-option-modifier 'control))


;; =======================================
;;; Emacs UI and behavior & Dropbox Config
;; =======================================
(use-package emacs
  :init
  (setq default-directory (dropbox/dir "org")
        temporary-file-directory (emacs/dir "tmp/"))

  :hook ((text-mode     . visual-line-mode))
         ;; (focus-in-hook . hy/deactivate-input-method))
  
  :custom
  ;; Dropbox sync 충돌 방지 (경로 로컬 격리)
  (create-lockfiles nil)                                          ; 충돌 링크(.#파일) 생성 억제
  (backup-directory-alist `(("." . ,(emacs/dir "backups/"))))     ; 백업 파일 로컬 이동
  (auto-save-file-name-transforms `((".*" ,(emacs/dir "auto-save/") t))) ; 임시 저장 로컬 이동

  ;; Win
  (split-window-preferred-direction 'horizontal)
  (window-combination-resize t)
  (even-window-sizes 'height-only)
  (window-sides-vertical nil)
  (switch-to-buffer-in-dedicated-window 'pop)
  ;; (split-height-threshold 35)      ; 세로가 35줄 이하이면 세로 분할 안 함
  ;; (split-width-threshold 85)       ; 가로가 85자 이상이면 가로 분할 선호
  (window-min-height 3)
  (window-min-width 30)

  ;; UI, 상태 정보
  (use-short-answers t)
  (column-number-mode t)
  (display-time-mode t)
  
  ;; 시각 효과, 가독성
  (line-spacing 0.2)
  (text-scale-mode-step 1.02)
  (frame-resize-pixelwise t)
  
  ;; 스크롤, 탐색
  (pixel-scroll-precision-mode t)
  (pixel-scroll-precision-use-momentum t)
  (pixel-scroll-precision-interpolate-page t)
  
  ;; 마크, 히스토리 
  (set-mark-command-repeat-pop t)
  (mark-ring-max 16)
  (global-mark-ring-max 32)
  
  ;; 편집 행동 관련
  (kill-whole-line 1)
  (next-line-add-newlines nil)
  (enable-recursive-minibuffers t)

  :config
  (global-font-lock-mode 1)
  (minibuffer-depth-indicate-mode 1)

  ;; 격리용 로컬 폴더가 없으면 자동으로 생성하는 안전장치
  (dolist (dir (list (emacs/dir "backups/") 
                     (emacs/dir "auto-save/") 
                     (emacs/dir "tmp/")))
    (unless (file-directory-p dir)
      (make-directory dir t)))
  
  :bind
  (("C-x f"       . toggle-frame-fullscreen)
   ("C-x <left>"  . hy/tile-frame-left)
   ("C-x <right>" . hy/tile-frame-right)
   ("C-x <down>"  . hy/tile-frame-center)
   ("C-x <up>"    . toggle-frame-maximized)
   ("C-x C-m"     . execute-extended-command)     ;M-x
   ("C-x 0"       . hy/simple-delete-window-dwim)
   ("<escape>"    . hy/prefix-with-ime-deactivation)
   ("M-;"         . comment-line)
   ("M-s u"       . hy/search-unified)
   ("C-a"         . hy/smart-beginning-of-line)
   ("C-g"         . hy/keyboard-quit-dwim)))


(use-package time
  :ensure nil
  :custom
  (display-time-24hr-format t)      ; 24-hour system
  (display-time-format "%m월 %d일(%a)%H:%M")
  ;; (display-time-format "%Y-%m-%d (%a) %H:%M")
  (display-time-day-and-date t)
  (display-time-load-average nil))  ; mode-line-misc-info average nil


;; =======================================
;;; Auto-revert (Dropbox Sync Optimization)
;; =======================================
(use-package autorevert
  :ensure nil
  :custom
  (auto-revert-interval 2)                ; [최적화] 60초에서 2초로 단축하여 실시간 동기화 체감 향상
  (auto-revert-check-vc-info nil)         ; 버전 관리 감지를 꺼서 성능 오버헤드 방지
  (global-auto-revert-non-file-buffers t) ; 파일이 아닌 버퍼(Agenda 등)도 함께 갱신
  :config
  (global-auto-revert-mode t)
  ;; Mac 화면 포커스가 돌아왔을 때(창 전환 시) Dropbox auto Sync
  (add-function :after after-focus-change-function
                (lambda ()
                  (when (and (frame-focus-state)
                             (fboundp 'auto-revert-buffers))
                    (auto-revert-buffers)))))


;; =======================================
;;; Bookmark
;; =======================================
(use-package bookmark
  :ensure nil
  :custom
  (bookmark-save-flag 1)
  (bookmark-sort-flag nil)
  (bookmark-default-file (emacs/dir "bookmarks")))


;; =======================================
;;; Register
;; =======================================
(use-package register
  :ensure nil
  :config
  (let ((conf-dir user-emacs-directory))
    (set-register ?i `(file . ,(emacs/dir "init.el")))
    (set-register ?l `(file . ,(emacs/dir "lisp/")))
    ;; (set-register ?r `(file . ,(concat org-dir "cReading.org")))
    ;; (set-register ?d `(file . ,(concat org-dir "Daily.org")))
    ;; (set-register ?n `(file . ,(concat org-dir "cNotes.org")))
    (set-register ?p `(file . ,(dropbox/dir "pdf")))
    (set-register ?P `(file . ,(dropbox/dir "Person"))))
  (set-register ?o `(file . ,default-directory))
  :custom
  (register-preview-delay 0.5))


;; =======================================
;;; Locale and Korean settings
;; =======================================
(use-package emacs
  :init
  (setenv "LANG" "ko_KR.UTF-8")
  (setenv "LC_COLLATE" "C")
  (advice-add 'set-language-environment-input-method :override #'ignore)
  (set-locale-environment "ko_KR.UTF-8")
  (advice-remove 'set-language-environment-input-method #'ignore)
  
  ;; 기본 입력기 설정
  (setq default-input-method "korean-hy-hangul")
  (prefer-coding-system 'utf-8)
  (set-default-coding-systems 'utf-8)
  (set-terminal-coding-system 'utf-8)
  (set-keyboard-coding-system 'utf-8)

  :config
  ;; [핵심 방어막] 전역에서 어떤 경로로든 존재하지 않는 입력기 호출 시 에러 방어 및 기본 자판 탈출
  (define-advice activate-input-method (:around (orig-fun input-method &rest args) prevent-unrecognized-error)
    "존재하지 않는 입력기 호출 시 에러를 방어하고 안전하게 기본 탈출합니다."
    (condition-case err
        (apply orig-fun input-method args)
      (error
       (message "⚠️ 입력기 오류 감지: %s. 안전 모드로 전환합니다." (error-message-string err))
       ;; 에러 발생 시 시스템이 먹통이 되지 않도록 hy-hangul을 재요구하거나 안전하게 입력기 해제
       (unless (assoc "korean-hy-hangul" input-method-alist)
         (require 'hy-hangul nil t))
       (deactivate-input-method)
       (message "✅ [입력기 초기화 완료] 시스템 안정 상태를 유지합니다."))))

  ;; korea-util.el의 하드코딩 회피 및 토글 구조 안정화
  (with-eval-after-load 'korea-util
    (advice-add 'toggle-korean-input-method :override
      (lambda ()
        (interactive)
        (if current-input-method
            (deactivate-input-method)
          (activate-input-method
           (or default-input-method
                (concat "korean-hangul" default-korean-keyboard))))))))


;; =======================================
;;; Fonts
;; =======================================  
(defun hy/org-fixed-pitch-faces ()
  (dolist (face '(org-table org-code org-block
                  org-block-begin-line org-block-end-line
                  org-checkbox org-date org-link org-quote))
    (set-face-attribute face nil
                        :family "D2Coding"
                        :inherit 'fixed-pitch)))

(use-package emacs
  :config
  (set-face-attribute 'default nil :family "Menlo" :height 180)
  (set-face-attribute 'fixed-pitch nil :family "Menlo" :height 1.0)
  (set-face-attribute 'variable-pitch nil :family "Noto Sans CJK KR" :height 1.0)
  ;; (setq face-font-rescale-alist '(("D2Coding" . 1.0)
  ;;                                 ("Noto Sans CJK KR" . 0.95)))
  (add-hook 'org-mode-hook
            (lambda ()
              (variable-pitch-mode 1)
              (hy/org-fixed-pitch-faces))))


;; =======================================
;;; Theme
;; =======================================
(use-package modus-themes
  :ensure nil)

(use-package ef-themes
  :ensure t
  :demand t
  :init
  (ef-themes-take-over-modus-themes-mode 1)
  :bind
  (("<f5>"   . modus-themes-rotate)
   ("C-<f5>" . modus-themes-select))
  :config
  (setq modus-themes-mixed-fonts t
        modus-themes-italic-constructs t)
  (modus-themes-load-theme 'ef-owl))


;; =======================================
;;; Session and Place Persistence
;; =======================================
(use-package savehist
  :ensure nil
  :demand t
  :init (savehist-mode 1)
  :custom
  (history-length 10))

(use-package saveplace
  :ensure nil
  :config (save-place-mode 1))


;; =======================================
;;; Icons
;; =======================================
(use-package nerd-icons
  :if (display-graphic-p)
  :custom (nerd-icons-font-family "Symbols Nerd Font"))

(use-package nerd-icons-dired
  :if (display-graphic-p)
  :hook (dired-mode . nerd-icons-dired-mode))

(use-package nerd-icons-completion
  :if (display-graphic-p)
  :after (marginalia nerd-icons)
  :config  (nerd-icons-completion-mode 1))


;; =======================================
;;; windmove
;; =======================================
(use-package windmove
  :ensure nil     ;built-in
  :bind
  (("C-S-<left>"  . windmove-left)
   ("C-S-<right>" . windmove-right)
   ("C-S-<up>"    . windmove-up)
   ("C-S-<down>"  . windmove-down)))


;; =======================================
;;; winner
;; =======================================
(use-package winner
  :ensure nil    ;built-in
  :init
  (winner-mode 1))


;; =======================================
;;; recentF
;; =======================================
(use-package recentf
  :init (recentf-mode 1)
  :custom
  (recentf-max-menu-items 15)
  (recentf-max-saved-items 15))


;; =======================================
;;; which-key
;; =======================================
(use-package which-key
  :ensure nil
  :init (which-key-mode)
  :custom
  (which-key-show-transient-maps t)
  (which-key-idle-delay 0.2))


;; =======================================
;;; Eshell
;; =======================================
(use-package eshell
  :defer t
  :custom
  (eshell-destroy-buffer-when-process-dies t))


;; =======================================
;;; Modeline
;; =======================================
(setq mode-line-right-align-edge 'right-margin)
;; (setq-default mode-line-front-space nil)
(setq-default mode-line-format
              '("%e "
                mode-line-front-space
                (:eval
                 (let* ((is-ko (and (boundp 'current-input-method) 
                                    (stringp current-input-method)
                                    (string-match-p "korean" current-input-method))))
                   (if is-ko
                       " 🇰🇷 "
		     " 🇺🇸 ")))
                " Ⓗ "
                mode-line-buffer-identification
                mode-line-frame-identification
                "  "
                mode-line-format-right-align
                mode-line-position
                " Ⓨ "
                mode-line-misc-info))


;; =======================================
;;; Battery display
;; =======================================
(use-package battery
  :if hy-Macbook-p
  :ensure nil
  :demand t
  :custom
  (battery-status-function 'battery-pmset)
  (battery-mode-line-format "Ⓑ %p%% ")
  :init
  (display-battery-mode 1))


;; =======================================
;;; Manual Session Management
;; =======================================
(use-package desktop
  :ensure nil
  :custom
  (desktop-path (list user-emacs-directory))
  (desktop-save 'if-exists)
  (desktop-buffers-not-to-save "\\(^\\*\\|\\.log$\\)")
  (desktop-save-mode nil) 
  :config
  (defun hy/desktop-save-at-point ()
    "Save all current buffers and window configurations."
    (interactive)
    (desktop-save user-emacs-directory)
    (message "✅ [Layout Saved] Current configuration has been recorded."))

  (defun hy/desktop-read-at-point ()
    "Restore the saved desktop session."
    (interactive)
    (unless (assoc "korean-hy-hangul" input-method-alist)
      (require 'hy-hangul nil t))
    (desktop-read user-emacs-directory)
    (message "✅ [Layout Restored] Previous session has been restored."))
  :bind
  (("C-x r S" . hy/desktop-save-at-point)   ; Save Layout
   ("C-x r R" . hy/desktop-read-at-point))) ; Restore Layout


;; =======================================
;;; Emacs Server Start (For Emacs Client)
;; =======================================
;; (require 'server)

;; (if (daemonp)
;;   ;; 1. terminal에서 emacs --daemon으로 실행
;;     (unless (server-running-p)
;;       (server-start)
;;       (message "🚀 Emacs daemon started successfully."))
;;   ;; 2. 일반 GUI(앱 아이콘 클릭 등)로 실행
;;   (message "ℹ️ Running in normal GUI mode (Server not started)."))


;; =======================================
;;; Emacs Server Dynamic Controller
;; =======================================
;; (defun hy/server-start ()
;;   "Emacs 서버를 동적으로 실행합니다. (평소 로딩 시간 제외용)"
;;   (interactive)
;;   (require 'server)
;;   (if (server-running-p)
;;       (message "ℹ️ Emacs 서버가 이미 실행 중입니다.")
;;     (server-start)
;;     (message "🚀 Emacs 서버가 성공적으로 시작되었습니다.")))

;; (defun hy/server-stop ()
;;   "실행 중인 Emacs 서버를 종료하고 기능을 제외합니다."
;;   (interactive)
;;   (if (and (fboundp 'server-running-p) (server-running-p))
;;       (progn
;;         (server-force-delete)
;;         (message "🛑 Emacs 서버가 안전하게 종료되었습니다."))
;;     (message "ℹ️ 현재 실행 중인 Emacs 서버가 없습니다.")))
