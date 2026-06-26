;;; early-init.el --- Early initialization -*- lexical-binding: t -*-
;; Server mode
;;
;; ======================================
;;; GC 최적화 (부팅 속도 극대화)
;; ======================================
(setq gc-cons-threshold (* 100 1024 1024)  ; 100MB - 시작 시
      gc-cons-percentage 0.6
      read-process-output-max (* 4 1024 1024))  ; 4MB

;; 파일 핸들러 임시 비활성화 (시작 성능 향상)
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
      ;; [조정] 파일 관련 최적화: init.el의 로컬 격리 세팅이 작동하도록 lockfile만 유지
      create-lockfiles nil
      ; auto-save-default nil  ; init.el에서 로컬 디렉토리로 안전하게 격리하므로 주석 처리
      ; make-backup-files nil   ; init.el에서 로컬 디렉토리로 안전하게 격리하므로 주석 처리
      ; auto-save-list-file-prefix nil
      ;; 추가 최적화
      idle-update-delay 1.0
      ffap-machine-p-known 'reject)  ; 네트워크 체크 비활성화

;; ======================================
;;; UI 초기 설정 (창 깜빡임 방지)
;; ======================================
(setq inhibit-startup-message t
      inhibit-startup-screen t
      initial-scratch-message nil
      visible-bell t
      use-dialog-box nil
      use-file-dialog nil)

;; UI 요소 제거 (early-init에서 처리, 툴바가 켜졌다가 꺼지는 깜빡임 사라짐)
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)

;; 좌우 여백 (0으로 바짝 붙였을 때 Org-mode 가독성이 답답하다면 두 줄 주석 처리)
(push '(left-fringe . 0) default-frame-alist)  
(push '(right-fringe . 0) default-frame-alist) 

;; 프레임 기본 크기 지정
(push '(width . 120) default-frame-alist)
(push '(height . 50) default-frame-alist)

;; ======================================
;;; Package 시스템 (Modern 최적화 필수)
;; ======================================
(setq package-enable-at-startup nil)

;;; early-init.el ends here
