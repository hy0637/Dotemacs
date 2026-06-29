;;; hy-radio-direct.el --- Direct radio control via mpv without external packages -*- lexical-binding: t; -*-

;; ======================================
;;; Variables
;; ======================================
(defvar hy-radio-process-name "hy-radio-mpv")
(defvar hy-radio-mmslist (expand-file-name "mmslist" (or (bound-and-true-p hy/lisp-path) user-emacs-directory)))
(defvar hy-radio-default-volume 80 "Default startup volume (0-100)")

;; ======================================
;;; Core Functions
;; ======================================
;;; ###autoload
(defun hy/radio-stop ()
  "Stop the currently running radio (mpv) process."
  (interactive)
  (if (get-process hy-radio-process-name)
      (progn
        (delete-process hy-radio-process-name)
        (message "⏹️ Radio playback stopped."))
    (message "No radio is currently playing.")))


;;; ###autoload
(defun hy/radio-play ()
  "Select a channel from mmslist and play it directly using mpv."
  (interactive)
  (if (not (file-exists-p hy-radio-mmslist))
      (error "Channel list file not found: %s" hy-radio-mmslist)
    (let* ((channels (with-temp-buffer
                       (insert-file-contents hy-radio-mmslist)
                       (let (res)
                         (goto-char (point-min))
                         (while (not (eobp))
                           (let ((line (string-trim (buffer-substring-no-properties (line-beginning-position) (line-end-position)))))
                             ;; Skip empty lines and comments starting with ';'
                             (unless (or (string-empty-p line) (string-prefix-p ";" line))
                               (let ((parts (split-string line "|")))
                                 (when (>= (length parts) 2)
                                   (push (cons (string-trim (car parts)) (string-trim (cadr parts))) res)))))
                           (forward-line 1))
                         (nreverse res))))
           (selected (completing-read "📻 Select Radio Station: " (mapcar #'car channels) nil t))
           (url (cdr (assoc selected channels))))
      (when url
        (hy/radio-stop) ; Stop existing process if any
        ;; Start mpv with specified volume and hidden UI
        (start-process hy-radio-process-name nil "mpv" 
                       "--no-video" 
                       "--no-terminal" 
                       (format "--volume=%d" hy-radio-default-volume)
                       "--msg-level=all=no"
                       url)
        (message "🎶 Now Playing: %s (Vol: %d%%)" selected hy-radio-default-volume)))))

;; ======================================
;;; Volume Control Functions
;; ======================================
;; (defun hy/radio-volume-up ()
;;   "Increase volume by 5%."
;;   (interactive)
;;   (hy/radio-send-command "add volume 5"))

;; (defun hy/radio-volume-down ()
;;   "Decrease volume by 5%."
;;   (interactive)
;;   (hy/radio-send-command "add volume -5"))

;; (defun hy/radio-send-command (command)
;;   "Send a command string directly to the mpv process."
;;   (let ((proc (get-process hy-radio-process-name)))
;;     (if (and proc (process-live-p proc))
;;         (progn
;;           (process-send-string proc (concat command "\n"))
;;           ;; Extract action name for the message (e.g., "volume +5")
;;           (message "Radio: %s" command))
;;       (message "No radio process found."))))


(provide 'hy-radio-direct)
;;; end hy-radio-direct
