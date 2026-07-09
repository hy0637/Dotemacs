;;; hy-org-health.el --- Blood pressure and health tracking -*- lexical-binding: t; -*-

;;; Code:
(require 'org)

(defvar hy/org-person-dir (dropbox/dir "Person/")
  "Directory for personal org files.")

(defvar hy/f-health (expand-file-name "Health.org" hy/org-person-dir))
(defvar hy/bp-start-date (encode-time 0 0 0 4 3 2026) "BP💊 start date.")
;; (defvar hy/get-bp-stats nil)

;;;###autoload
(defun hy/bp-parse-table (&optional start-date end-date)
  "Parse Health.org BP table. Returns list of (sys dia pul) plists."
  (when (file-exists-p hy/f-health)
    (with-current-buffer (find-file-noselect hy/f-health)
      (save-excursion
        (save-restriction
          (widen)
          (goto-char (point-min))
          (let (rows)
            (while (re-search-forward
                    "^|\\s-*\\[\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)" nil t)
              (let* ((row-date (date-to-time (match-string 1)))
                     (cols (org-split-string (thing-at-point 'line) "|"))
                     (sys (and (> (length cols) 1) (string-to-number (string-trim (nth 1 cols)))))
                     (dia (and (> (length cols) 2) (string-to-number (string-trim (nth 2 cols)))))
                     (pul (and (> (length cols) 3) (string-to-number (string-trim (nth 3 cols))))))
                (when (and sys (> sys 0)
                           (or (not start-date) (time-less-p start-date row-date))
                           (or (not end-date)   (time-less-p row-date end-date)))
                  (push (list sys dia pul) rows))))
            rows))))))

;;;###autoload
(defun hy/bp-averages (&optional start-date end-date)
  "Return (avg-sys avg-dia avg-pul count) for BP rows."
  (let ((rows (hy/bp-parse-table start-date end-date)))
    (when rows
      (let ((n (float (length rows))))
        (list (/ (apply '+ (mapcar #'car rows)) n)
              (/ (apply '+ (mapcar #'cadr rows)) n)
              (/ (apply '+ (mapcar #'caddr rows)) n)
              (length rows))))))

;;;###autoload
(defun hy/get-bp-stats ()
  "Overall BP averages from Health.org."
  (hy/bp-averages))

;;;###autoload
(defun hy/get-recent-bp-stats (days-offset &optional period)
  "Avg systolic for PERIOD days ending DAYS-OFFSET days ago."
  (let* ((period (or period 7))
         (end   (time-subtract (current-time) (days-to-time days-offset)))
         (start (time-subtract end (days-to-time period)))
         (rows   (hy/bp-parse-table start end)))
    (when rows (/ (apply '+ (mapcar #'car rows)) (float (length rows))))))

;;;###autoload
(defun hy/Bdays ()
  "Return string like 'BP nD: 시간대/'."
  (let* ((diff-days (1+ (floor (/ (float-time (time-subtract (current-time) hy/bp-start-date)) 86400))))
         (hour (string-to-number (format-time-string "%H")))
         (time-tag (cdr (seq-find (lambda (x) (< hour (car x)))
                                  '((6 . "새벽") (12 . "오전") (14 . "점심")
                                    (18 . "오후") (21 . "저녁") (25 . "밤"))))))
    (format "BP %dD: %s/" diff-days time-tag)))

;;;###autoload
(defun hy/bp-report ()
  "Display weekly BP report in echo area."
  (interactive)
  (let* ((this-week (hy/get-recent-bp-stats 0))
         (last-week (hy/get-recent-bp-stats 7))
         (diff (and this-week last-week (- this-week last-week))))
    (if this-week
        (message "📎주간 BP 리포트: 이번주 %.1f %s"
                 this-week
                 (if last-week
                     (format "(지난주 %.1f 대비 %+.1f %s)"
                             last-week diff (if (<= diff 0) "▼ 개선!" "▲ 주의"))
                   "(지난주 데이터 없음)"))
      (message "No BP data found."))))

;;;###autoload
(defun hy/org-capture-finalize-bp ()
  "Handle post-finalize actions for blood pressure capture (key: 'b')."
  (when (equal (org-capture-get :key) "b")
    (let ((today-str (format-time-string "%Y-%m-%d")))
      (with-current-buffer (find-file-noselect (expand-file-name hy/f-health))
        (save-excursion
          (goto-char (point-min))
          (when (re-search-forward "^\\*+ .*혈압 측정" nil t)
            (let ((last-repeat (org-entry-get (point) "LAST_REPEAT")))
              (unless (and last-repeat
                           (string-match today-str last-repeat))
                (org-todo "DONE")
                (save-buffer)))))))))

(defun hy/org-capture-report-bp-after-finalize ()
  "Show BP report after capture finalize is completely done."
  (when (equal (org-capture-get :key) "b")
    (hy/bp-report)))

(add-hook 'org-capture-after-finalize-hook #'hy/org-capture-report-bp-after-finalize)

;;;###autoload
(defun hy/show-bp-stats-by-tag ()
  "Generate BP report aggregated by Time/Status patterns."
  (interactive)
  (let ((stats-hash  (make-hash-table :test 'equal))
        (time-order  '("새벽" "오전" "점심" "오후" "저녁" "밤"))
        (total       (list 0.0 0.0 0.0 0))
        stats-list)
    (with-current-buffer (find-file-noselect (expand-file-name hy/f-health))
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward
                "| +\\([0-9.]+\\) | +\\([0-9.]+\\) | +\\([0-9.]+\\) | .*? \\([^ \t\n|/]+\\)/\\([^ \t\n| ]+\\)"
                nil t)
          (let* ((sys (string-to-number (match-string 1)))
                 (dia (string-to-number (match-string 2)))
                 (pul (string-to-number (match-string 3)))
                 (tag (concat (match-string 4) "/" (match-string 5)))
                 (cur (gethash tag stats-hash '(0.0 0.0 0.0 0))))
            (puthash tag (list (+ (nth 0 cur) sys) (+ (nth 1 cur) dia)
                               (+ (nth 2 cur) pul) (1+ (nth 3 cur))) stats-hash)
            (setq total (list (+ (nth 0 total) sys) (+ (nth 1 total) dia)
                              (+ (nth 2 total) pul) (1+ (nth 3 total))))))))

    (maphash (lambda (k v) (push (cons k v) stats-list)) stats-hash)
    (setq stats-list
          (sort stats-list
                (lambda (a b)
                  (let ((ia (cl-position (car (split-string (car a) "/")) time-order :test #'equal))
                        (ib (cl-position (car (split-string (car b) "/")) time-order :test #'equal)))
                    (if (and ia ib (not (= ia ib))) (< ia ib) (string< (car a) (car b)))))))

    (with-current-buffer (get-buffer-create "*Blood Pressure Stats*")
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "=== 통합 혈압 분석 리포트 ===\n")
        (insert (format "분석 일시: %s\n\n" (format-time-string "%Y-%m-%d %H:%M")))
        (insert (format "%-22s | %-8s | %-8s | %-5s\n" "상태 (시간대/상태)" "수축기" "이완기" "횟수"))
        (insert (make-string 62 ?-) "\n")
        (dolist (entry stats-list)
          (let* ((tag (car entry)) (d (cdr entry)) (n (nth 3 d)))
            (insert (format "%-22s | %-8.1f | %-8.1f | %-5d\n"
                            tag (/ (nth 0 d) (float n)) (/ (nth 1 d) (float n)) n))))
        (let ((n (nth 3 total)))
          (when (> n 0)
            (insert (make-string 62 ?-) "\n")
            (insert (format "전체 평균               | %-8.1f | %-8.1f | %-8.1f (총횟수 %d)\n"
                            (/ (nth 0 total) n) (/ (nth 1 total) n) (/ (nth 2 total) n) n))))
        (special-mode)
        (goto-char (point-min)))
      (pop-to-buffer (current-buffer)))))

(provide 'hy-org-health)
;;; hy-org-health.el ends here
