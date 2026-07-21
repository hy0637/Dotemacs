;;; -*- lexical-binding: t; -*-
;; .emacs.d/lisp/hy-win-useful.el
;;
;;; ver 20260708
;;
;;

(defun hy/get-display-workarea ()
  "Returns the usable work area of the current monitor,
excluding the Dock and Menu bar."
  (let* ((attrs (frame-monitor-attributes))
         (workarea (alist-get 'workarea attrs)))
    ;; workarea: (x y width height)
    (list (nth 0 workarea)
          (nth 1 workarea)
          (nth 2 workarea)
          (nth 3 workarea))))


;;;###autoload
(defun hy/tile-frame-dwim ()
  "Emacs 프레임 화면 스냅 및 레이아웃 제어 (C-x f)

         [↑ / i] 전체화면
   [← / j] 왼쪽  [→ / l] 오른쪽     [s] 사이드바 토글
         [↓ / m] 중앙 2/3           [r] 창 크기 조절 모드(Resize)"
  (interactive)
  (message "프레임 제어: [←/j]왼쪽 [→/l]오른쪽 [↓/m]중앙 [↑/i]전체 | [s]사이드바 [r]리사이즈 (종료: 다른키)")
  (set-transient-map
   (let ((map (make-sparse-keymap))
         (area (hy/get-display-workarea)))
     (let* ((x      (nth 0 area))
            (y      (nth 1 area))
            (width  (nth 2 area))
            (height (nth 3 area))
            (half-w (/ width 2))
            
            ;; 스냅 함수들
            (snap-left   (lambda () (interactive) (set-frame-position nil x y) (set-frame-size nil half-w height t) (hy/tile-frame-dwim)))
            (snap-right  (lambda () (interactive) (set-frame-position nil (+ x half-w) y) (set-frame-size nil half-w height t) (hy/tile-frame-dwim)))
            (snap-center (lambda () (interactive) (let ((w (/ (* width 2) 3))) (set-frame-position nil (+ x (/ (- width w) 2)) y) (set-frame-size nil w height t)) (hy/tile-frame-dwim)))
            (snap-full   (lambda () (interactive) (toggle-frame-fullscreen) (hy/tile-frame-dwim)))
            
            ;; 추가 동작 함수들
            (action-sidebar (lambda () (interactive)
                              (hy/toggle-sidebar-layout-20)
                              (hy/tile-frame-dwim))) ; 실행 후 대기모드 유지
            (action-resize  (lambda () (interactive)
                              ;; 리사이즈는 자체 대기 루프가 있으므로, 
                              ;; 프레임 스냅 모드를 끝내면서 리사이즈 모드로 바통을 넘깁니다.
                              (hy/interactive-window-resize-all))))

       ;; 방향 및 이동 바인딩
       (define-key map (kbd "<left>")  snap-left)
       (define-key map (kbd "j")       snap-left)
       (define-key map (kbd "<right>") snap-right)
       (define-key map (kbd "l")       snap-right)
       (define-key map (kbd "<down>")  snap-center)
       (define-key map (kbd "m")       snap-center)
       (define-key map (kbd "<up>")    snap-full)
       (define-key map (kbd "i")       snap-full)

       ;; 창/동작 관련 기능 확장 바인딩
       (define-key map (kbd "s")       action-sidebar)
       (define-key map (kbd "r")       action-resize)

       map))))


;;;###autoload
(defun hy/toggle-sidebar-layout-20 ()
  "Set the leftmost window's width to exactly 20% of the frame.
If only one window exists, it automatically splits the window right (C-x 3)
and adjusts the left window to 20% and the right window to 80%."
  (interactive)
  (let ((windows (window-list)))
    ;; 1. 창이 1개인 경우 자동으로 우측 분할 처리
    (when (= (length windows) 1)
      (split-window-right)
      (setq windows (window-list))) ; 분할 후 창 목록 갱신
    
    ;; 2. 가장 왼쪽에 배치된 창 찾기
    (let* ((leftmost-window (car (sort windows (lambda (w1 w2)
                                                 (< (car (window-edges w1))
                                                    (car (window-edges w2)))))))
           (total-width (frame-width))
           (target-width (round (* total-width 0.20)))
           (current-width (window-total-width leftmost-window))
           (delta (- target-width current-width)))
      
      ;; 3. 가장 왼쪽 창을 잠시 안전하게 선택하여 크기를 정확히 조절
      (save-selected-window
        (select-window leftmost-window)
        (condition-case nil
            (window-resize leftmost-window delta t)
          (error
           ;; window-resize가 실패할 경우를 대비한 하드웨어 스케일러 백업
           (adjust-window-trailing-edge leftmost-window delta t))))
      
      (message "Sidebar layout fixed: Left window allocated 20%% of frame"))))


;;;###autoload
(defun hy/interactive-window-resize-all ()
  "방향키(←/→/↑/↓) 또는 문자키로 창의 너비와 높이를 제한 없이 조절.
임시로 최소 크기 제한을 해제하여 원하는 만큼 자유롭게 축소."
  (interactive)
  (message "창 크기 조절: [←/j] 축소, [→/l] 확대 | [↑/i] 축소, [↓/m] 확대 (종료: 다른 키)")
  (let ((window-min-width 1)
        (window-min-height 1)
        (window-size-fixed nil))
    (set-transient-map
     (let ((map (make-sparse-keymap)))
       
       ;; 1. 가로(너비) 줄이기: <left> 와 h
       (let ((left-func (lambda () (interactive)
                          (let ((window-min-width 1)) (window-resize nil -3 t))
                          (hy/interactive-window-resize-all))))
         (define-key map (kbd "<left>") left-func)
         (define-key map (kbd "j") left-func))

       ;; 2. 가로(너비) 늘리기: <right> 와 l
       (let ((right-func (lambda () (interactive)
                           (let ((window-min-width 1)) (window-resize nil 3 t))
                           (hy/interactive-window-resize-all))))
         (define-key map (kbd "<right>") right-func)
         (define-key map (kbd "l") right-func))

       ;; 3. 세로(높이) 줄이기: <up> 과 k
       (let ((up-func (lambda () (interactive)
                        (let ((window-min-height 1)) (window-resize nil -3 nil))
                        (hy/interactive-window-resize-all))))
         (define-key map (kbd "<up>") up-func)
         (define-key map (kbd "i") up-func))

       ;; 4. 세로(높이) 늘리기: <down> 과 m (요청하신 부분)
       (let ((down-func (lambda () (interactive)
                          (let ((window-min-height 1)) (window-resize nil 3 nil))
                          (hy/interactive-window-resize-all))))
         (define-key map (kbd "<down>") down-func)
         (define-key map (kbd "m") down-func))

       map))))


;;;###autoload
(defun hy/caffeine-on ()
  "Prevent macOS from sleeping for a selected duration.
Prompts the user to choose between 30 minutes or 60 minutes.
Uses macOS built-in caffeinate command with -d flag to keep display awake."
  (interactive)
  (let* ((choice (completing-read "Caffeine duration: " '("30 min" "60 min")))
         (seconds (if (string= choice "30 min") 1800 3600)))
    (start-process "caffeinate" nil "caffeinate" "-d" "-t" (number-to-string seconds))
    (message "Caffeine ON for %s" choice)))


;;;###autoload
(defun hy/caffeine-off ()
  "Allow macOS to sleep normally by terminating the caffeinate process.
Kills any running caffeinate process started by caffeine-on."
  (interactive)
  (shell-command "pkill caffeinate")
  (message "Caffeine OFF"))


;;;###autoload
(defun hy/simple-delete-window-dwim ()
  ;;https://github.com/protesilaos
  "Do What I Mean to delete the current THING.
When there is more than one window, THING is a window.
When there are more than one `tab-bar-mode' tabs, THING is a tab.
Else THING is a frame if frames are more than one."
  (declare (interactive-only t))
  (interactive)
  (cond
   ((length> (window-list) 1)
    (delete-window))
   ((and (featurep 'tab-bar)
         (length> (tab-bar-tabs) 1))
    (tab-close))
   ((length> (frame-list) 1)
    (delete-frame))
   (t
    (user-error "Nothing to delete"))))



(provide 'hy-win-useful)
;;; hy-win-useful.el ends here
