;;; hy-dired-custom.el --- Custom Dired configuration -*- lexical-binding: t; -*-

;; ======================================
;;; Helper Function
;; ======================================
(defcustom hy/dired-external-regexp "\\.pdf\\|\\.docx\\|\\.xlsx\\|\\.hwp\\|\\.hwpx"
  "List of file extensions to be opened with an external program."
  :type 'string
  :group 'dired)


(defun hy/dired-open-dwim ()
  "Open file in Emacs or via macOS 'open' command based on its extension."
  (interactive)
  (let* ((file (dired-get-file-for-visit))
         (ext (file-name-extension file t)))
    (if (and ext (string-match-p hy/dired-external-regexp ext))
	;; Open with external app (macOS 'open' command)
        (progn
          (start-process "dired-external-open" nil "open" file)
          (message "외부 앱 실행: %s" (file-name-nondirectory file)))
      ;; Open internally (text files, directories, etc.)
      (if (file-directory-p file)
          (dired-find-file)
        (find-file file)))))


(defun hy/dired-move-to-pdf-folder-safe ()
  "Move marked files to '/pdf' safely."
  (interactive)
  (let* ((target-dir "../pdf/")
         (expanded-target (expand-file-name target-dir))
         (files (dired-get-marked-files)))
    (unless (file-exists-p expanded-target)
      (make-directory expanded-target t))
    (condition-case nil
        (progn
          (dired-do-rename-regexp ".*" expanded-target nil t)
          (revert-buffer)
          (message "%d files moved to %s." (length files) target-dir))
      (quit (message "Move canceled."))
      (error (message "Error occurred during move.")))))


;; ======================================
;;; Dired Main Configuration
;; ======================================
(use-package dired
  :ensure nil
  :custom
  (dired-listing-switches "-AGFhlv --group-directories-first --time-style=long-iso")
  (dired-dwim-target t)
  (dired-recursive-copies 'always)
  (dired-recursive-deletes 'always)
  (dired-auto-revert-buffer t)
  (delete-by-moving-to-trash t)
  (dired-free-space nil)
  :bind
  (:map dired-mode-map
   ("RET" . hy/dired-open-dwim)
   ("C-<return>" . dired-do-open)
   ("M" . hy/dired-move-to-pdf-folder-safe)
   ("/" . consult-line)))


(provide 'hy-dired-custom)
;;; end hy-dired-custom