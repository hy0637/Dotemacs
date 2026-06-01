;;; hy-app.el --- configuration -*- lexical-binding: t; -*-

;;; CODE;


;; =======================================
;;; magit
;; =======================================
(use-package magit
  :ensure t
  :bind ("C-x g" . magit-status)
  :custom
  ;; Magit이 전체 화면을 차지하지 않고, 현재 창 구성을 최대한 유지
  (magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))


;; =======================================
;;; project
;; =======================================
(use-package project
  :ensure nil
  :config
  (setq project-vc-extra-root-markers '("init.el")))


;; =======================================
;;; expand-region
;; =======================================
(use-package expand-region
  :ensure nil
  :bind (("C-="   . er/expand-region)
         ("C-M-=" . er/contract-region)))


;; =======================================
;;; eldoc
;; =======================================
(use-package eldoc
  :ensure nil
  :diminish eldoc-mode
  :hook (emacs-lisp-mode . eldoc-mode))


;; =======================================
;;; Helpful
;; =======================================
(use-package helpful
  :bind
  (("C-h f" . helpful-callable)   ; 함수, 매크로 등 호출 가능한 모든 것
   ("C-h v" . helpful-variable)   ; 변수 설정 확인 시 유용
   ("C-h k" . helpful-key)        ; 특정 키가 어떤 기능을 하는지 확인
   ("C-h x" . helpful-command)    ; M-x 명령 확인
   ("C-c C-d" . helpful-at-point) ; 현재 커서 아래의 심볼 바로 확인
   ("C-h F" . helpful-function))  ; 호출 가능 여부와 상관없이 '함수'만 확인
  :custom
  (helpful-max-lines 50))



;; =======================================
;;; view-mode
;; =======================================
(use-package view
  :ensure nil
  :bind
  (:map view-mode-map
        ("n" . scroll-up-line)    ; 화면을 아래로 (텍스트를 위로)
        ("p" . scroll-down-line)  ; 화면을 위로 (텍스트를 아래로)
        ("e" . hy/view-mode-edit-instantly))
  
  :hook (view-mode . hy/view-mode-visual-setup) ; Hook 설정
  
  :config
  (setq view-read-only t))

(defun hy/view-mode-visual-setup ()
  "view-mode 진입/해제 시 커서 모양과 줄 하이라이트만 변경합니다."
  (if view-mode
      (progn
        (hl-line-mode 1)
        ;; 읽기 모드일 때: 언더바(_) 모양 커서 (두께 3)
        (setq-local cursor-type '(hbar . 1)))
    (progn
      (hl-line-mode -1)
      ;; 편집 모드로 복귀 시: 원래 테마의 기본 커서(보통 box)로 복구
      (kill-local-variable 'cursor-type))))

(defun hy/view-mode-edit-instantly ()
  "view-mode를 즉시 종료하고 편집 모드로 전환합니다."
  (interactive)
  (when view-mode
    (view-mode -1)
    (message "📝 편집 모드")))


(provide 'hy-app)
;;; hy-app.el ends here
