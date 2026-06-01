;;; early-init.el --- Early initialization -*- lexical-binding: t -*-

;; ======================================
;;; GC 최적화
;; ======================================
(setq gc-cons-threshold (* 100 1024 1024)  ; 100MB - 시작 시
      gc-cons-percentage 0.6
      read-process-output-max (* 4 1024 1024))  ; 4MB

;; 파일 핸들러 임시 비활성화
(defvar hy--file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)

;; 시작 후 GC 설정 복원
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 16 1024 1024)  ; 16MB
                  gc-cons-percentage 0.1
                  file-name-handler-alist hy--file-name-handler-alist)
            (garbage-collect)))  ; 명시적 GC 실행

;; ======================================
;;; 성능 최적화
;; ======================================
(setq frame-inhibit-implied-resize t
      inhibit-compacting-font-caches t
      ;; 파일 관련 최적화
      auto-save-default nil
      make-backup-files nil
      create-lockfiles nil
      auto-save-list-file-prefix nil
      ;; 추가 최적화
      idle-update-delay 1.0
      ffap-machine-p-known 'reject)  ; 네트워크 체크 비활성화

;; ======================================
;;; UI 초기 설정
;; ======================================
(setq inhibit-startup-message t
      inhibit-startup-screen t
      initial-scratch-message nil
      visible-bell t
      use-dialog-box nil
      use-file-dialog nil)

;; UI 요소 제거 (early-init에서 처리하면 깜빡임 방지)
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(push '(left-fringe . 0) default-frame-alist)  ; 왼쪽 회색 여백 제거,
					       ; 답답하면 1
(push '(right-fringe . 0) default-frame-alist) ; 오른쪽 회색 여백 제거, 답답하면 1

;; 프레임 크기 지정
(push '(width . 120) default-frame-alist)
(push '(height . 50) default-frame-alist)

;; ======================================
;;; Package 시스템
;; ======================================
(setq package-enable-at-startup nil)

;;; early-init.el ends here
