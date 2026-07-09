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
(defun hy/tile-frame-left ()
  "Snap the Emacs frame to the Left half of the screen."
  (interactive)
  (let* ((area (hy/get-display-workarea))
         (x      (nth 0 area))
         (y      (nth 1 area))
         (width  (nth 2 area))
         (height (nth 3 area))
         (half-w (/ width 2)))
    (set-frame-position nil x y)
    (set-frame-size nil half-w height t)) ; t = pixel 단위
  (message "◧ Moved to Left Half"))


;;;###autoload
(defun hy/tile-frame-right ()
  "Snap the Emacs frame to the Right half of the screen."
  (interactive)
  (let* ((area (hy/get-display-workarea))
         (x      (nth 0 area))
         (y      (nth 1 area))
         (width  (nth 2 area))
         (height (nth 3 area))
         (half-w (/ width 2)))
    (set-frame-position nil (+ x half-w) y)
    (set-frame-size nil half-w height t))
  (message "◨ Moved to Right Half"))


;;;###autoload
(defun hy/tile-frame-center ()
  "Snap the Emacs frame to the center 2/3 of the screen."
  (interactive)
  (let* ((area   (hy/get-display-workarea))
         (x      (nth 0 area))
         (y      (nth 1 area))
         (width  (nth 2 area))
         (height (nth 3 area))
         (two-thirds-w (/ (* width 2) 3))
         (offset-x    (/ (- width two-thirds-w) 2)))
    (set-frame-position nil (+ x offset-x) y)
    (set-frame-size nil two-thirds-w height t))
  (message "▣ center 2/3"))


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
  "방향키(←/→/↑/↓)로 창의 너비와 높이 제한 없이 조절.
임시로 최소 크기 제한을 해제하여 원하는 만큼 자유롭게 축소."
  (interactive)
  (message "창 크기 조절: [←/→] 너비 조절, [↑/↓] 높이 조절 (종료: 다른 키)")
  (let ((window-min-width 1)
        (window-min-height 1)
        (window-size-fixed nil))
    (set-transient-map
     (let ((map (make-sparse-keymap)))
       ;; 가로(너비) 조절
       (define-key map (kbd "<left>")
                   (lambda () (interactive)
                     (let ((window-min-width 1)) (window-resize nil -3 t))
                     (hy/interactive-window-resize-all)))
       (define-key map (kbd "<right>")
                   (lambda () (interactive)
                     (let ((window-min-width 1)) (window-resize nil 3 t))
                     (hy/interactive-window-resize-all)))
       ;; 세로(높이) 조절
       (define-key map (kbd "<up>")
                   (lambda () (interactive)
                     (let ((window-min-height 1)) (window-resize nil -3 nil))
                     (hy/interactive-window-resize-all)))
       (define-key map (kbd "<down>")
                   (lambda () (interactive)
                     (let ((window-min-height 1)) (window-resize nil 3 nil))
                     (hy/interactive-window-resize-all)))
       map))))
(global-set-key (kbd "C-x {") #'hy/interactive-window-resize-all)


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
