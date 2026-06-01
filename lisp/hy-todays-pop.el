;;; hy-todays-pop.el --- Today's information display -*- lexical-binding: t; -*-

;;; Commentary:
;; Display today's date, agenda, and random quotes from cReading.org
;; Holidays are now integrated via org-agenda (no separate holiday lookup needed)
;; OPTIMIZED: Added caching, improved error handling, reduced timeouts

;;; Code:

;; ======================================
;;; Global Dependencies
;; ======================================
(require 'url)
(require 'xml)
(require 'json)
(require 'dom)
(require 'hy-search)

;; ======================================
;;; Configuration Variables
;; ======================================
(defvar kasi-api-key nil
  "KASI API key for lunar calendar and tide data.")

(defvar nokdong-tide-obs-code "SO_0761" 
  "Nokdong port observation code for tide forecast API.")

(defvar hy-weather-location "도양읍"
  "Default location for weather information.")

(defvar hy-weather-format-template "- %s, 최저/최고 %s/%s, 어제보다 %s"
  "Weather display format template.
Format placeholders:
  1st %s = weather status (e.g., '오전 10%% 맑음 오후 10%% 맑음')
  2nd %s = lowest temperature (e.g., '-2°')
  3rd %s = highest temperature (e.g., '11°')
  4th %s = comparison with yesterday (e.g., '3° 높아요')")

;; OPTIMIZED: 캐시 변수들 추가
(defvar hy/--weather-cache nil
  "Cache for weather data: (timestamp . weather-string)")

(defvar hy/--lunar-cache nil
  "Cache for lunar data: ((date . lunar-info) ...)")

(defvar hy/--tide-cache nil
  "Cache for tide data: ((date . tide-times) ...)")

;; ======================================
;;; Helper Functions
;; ======================================
;; OPTIMIZED: URL 요청 통합 함수 추가 (타임아웃 단축 및 에러 핸들링 강화)
(defun hy/--fetch-url-with-timeout (url &optional timeout)
  "Fetch URL with TIMEOUT (default 2 seconds) and error handling.
Returns buffer or nil on failure."
  (condition-case err
      (let ((url-request-extra-headers '(("User-Agent" . "Emacs"))))
        (url-retrieve-synchronously url t nil (or timeout 2)))
    (error 
     (message "URL fetch failed: %s" (error-message-string err))
     nil)))

;; ======================================
;;; KASI API Functions
;; ======================================
(defun kasi-load-api-key ()
  "Load API key from lunar_api file."
  (let ((key-file (expand-file-name "lunar_api" 
                                    (file-name-directory 
                                     (or load-file-name buffer-file-name)))))
    (unless (file-exists-p key-file)
      (error "lunar_api 파일을 찾을 수 없습니다: %s" key-file))
    (with-temp-buffer
      (insert-file-contents key-file)
      (setq kasi-api-key (string-trim (buffer-string))))))

;; Initialize API key on load
(unless kasi-api-key
  (kasi-load-api-key))

(defun kasi-get-xml-text (item-node tag)
  "Extract text content from TAG in ITEM-NODE."
  (when-let ((child (car (xml-get-children item-node tag))))
    (car (xml-node-children child))))

;; OPTIMIZED: 캐싱 및 타임아웃 개선
(defun kasi-get-lunar-date (year month day)
  "Fetch lunar date for given YEAR, MONTH, DAY from KASI API with caching."
  (unless kasi-api-key (kasi-load-api-key))
  (let ((cache-key (format "%s-%s-%s" year month day)))
    ;; 캐시에서 먼저 확인
    (or (alist-get cache-key hy/--lunar-cache nil nil #'string=)
        ;; 캐시 미스 시 API 호출 (타임아웃 3초로 단축)
        (when-let ((buffer (hy/--fetch-url-with-timeout
                            (format "http://apis.data.go.kr/B090041/openapi/service/LrsrCldInfoService/getLunCalInfo?solYear=%s&solMonth=%s&solDay=%s&ServiceKey=%s"
                                    year month day kasi-api-key)
                            3)))
          (unwind-protect
              (with-current-buffer buffer
                (goto-char (point-min))
                (when (re-search-forward "\n\n" nil t)
                  (when-let* ((xml-data (xml-parse-region (point) (point-max)))
                              (response (car xml-data))
                              (body (car (xml-get-children response 'body)))
                              (items (car (xml-get-children body 'items)))
                              (item (car (xml-get-children items 'item)))
                              (result (list :year (kasi-get-xml-text item 'lunYear)
                                           :month (kasi-get-xml-text item 'lunMonth)
                                           :day (kasi-get-xml-text item 'lunDay)
                                           :leap (kasi-get-xml-text item 'lunLeapmonth))))
                    ;; 결과 캐싱 (최근 7일만 유지)
                    (push (cons cache-key result) hy/--lunar-cache)
                    (when (> (length hy/--lunar-cache) 7)
                      (setq hy/--lunar-cache (seq-take hy/--lunar-cache 7)))
                    result)))
            ;; OPTIMIZED: 버퍼 존재 확인 후 킬
            (when (buffer-live-p buffer)
              (kill-buffer buffer)))))))

(defun hy/calculate-muldae (lunar-day)
  "Calculate tide cycle position from LUNAR-DAY (8-cycle system for Nokdong)."
  (let ((day (string-to-number lunar-day)))
    (cond
     ((<= 1 day 7) (+ day 7))
     ((= day 8) 0)
     ((<= 9 day 15) (- day 8))
     ((<= 16 day 22) (+ (- day 16) 8))
     ((= day 23) 0)
     ((<= 24 day 30) (- day 23))
     (t 1))))

(defun hy/lunar-date-string ()
  "Return today's lunar date string in format: (음) YYYY-MM-DD."
  (let* ((now (decode-time))
         (year (format "%04d" (nth 5 now)))
         (month (format "%02d" (nth 4 now)))
         (day (format "%02d" (nth 3 now)))
         (lunar (kasi-get-lunar-date year month day)))
    (if lunar
        (format " (음) %s-%s-%s%s"
                (plist-get lunar :year)
                (plist-get lunar :month)
                (plist-get lunar :day)
                (if (string= (plist-get lunar :leap) "윤") " (윤)" ""))
      " (음력 조회 실패)")))

;; ======================================
;;; Tide API Functions
;; ======================================
(defun nokdong-tide-parse-json (json-string)
  "Parse tide forecast JSON-STRING and extract data."
  (condition-case nil
      (let* ((json-object-type 'hash-table)
             (json-array-type 'list)
             (json-key-type 'string)
             (data (json-read-from-string json-string))
             (header (gethash "header" data))
             (body (gethash "body" data)))
        (when (string= (gethash "resultCode" header) "00")
          (when-let* ((items (gethash "items" body))
                      (tide-data (gethash "item" items)))
            (list :data (if (listp tide-data) tide-data (list tide-data))))))
    (error nil)))

(defun nokdong-tide-format-tide-times (tide-data date-str)
  "Format TIDE-DATA for DATE-STR into (HIGH-TIMES . LOW-TIMES) cons."
  (let ((target-date (format "%s-%s-%s" 
                             (substring date-str 0 4)
                             (substring date-str 4 6)
                             (substring date-str 6 8)))
        high-times low-times)
    (dolist (item tide-data)
      (when-let* ((predc-dt (gethash "predcDt" item))
                  (predc-date (substring predc-dt 0 10))
                  (time-only (substring predc-dt 11 16))
                  ((string= predc-date target-date)))
        (let ((extr-se (gethash "extrSe" item)))
          (cond 
           ((member extr-se '("1" "3")) (push time-only high-times))
           ((member extr-se '("2" "4")) (push time-only low-times))))))
    (cons (string-join (sort high-times #'string<) " ")
          (string-join (sort low-times #'string<) " "))))

;; OPTIMIZED: 캐싱 및 타임아웃 개선
(defun nokdong-tide-fetch-tide-times (date-str)
  "Fetch tide times for DATE-STR and return (HIGH-TIMES . LOW-TIMES) with caching."
  ;; 캐시에서 먼저 확인
  (or (alist-get date-str hy/--tide-cache nil nil #'string=)
      ;; 캐시 미스 시 API 호출 (타임아웃 3초로 단축)
      (when-let ((buffer (hy/--fetch-url-with-timeout
                          (format "https://apis.data.go.kr/1192136/tideFcstHghLw/GetTideFcstHghLwApiService?serviceKey=%s&obsCode=%s&reqDate=%s&type=json&numOfRows=5"
                                  kasi-api-key nokdong-tide-obs-code date-str)
                          3)))
        (unwind-protect
            (with-current-buffer buffer
              (goto-char (point-min))
              (when (re-search-forward "^$" nil t)
                (forward-char)
                (delete-region (point-min) (point))
                (when-let* ((parsed (nokdong-tide-parse-json (buffer-string)))
                            (tide-data (plist-get parsed :data))
                            (result (nokdong-tide-format-tide-times tide-data date-str)))
                  ;; 결과 캐싱 (최근 7일만 유지)
                  (push (cons date-str result) hy/--tide-cache)
                  (when (> (length hy/--tide-cache) 7)
                    (setq hy/--tide-cache (seq-take hy/--tide-cache 7)))
                  result)))
          ;; OPTIMIZED: 버퍼 존재 확인 후 킬
          (when (buffer-live-p buffer)
            (kill-buffer buffer))))))

(defun hy/format-tide-info (&optional days-offset)
  "음력(물때)과 조석 시각을 각각 독립적으로 시도하여 결과를 반환합니다."
  (let* ((offset (or days-offset 0))
         (target-time (time-add (current-time) (days-to-time offset)))
         (decoded (decode-time target-time))
         (year (format "%04d" (nth 5 decoded)))
         (month (format "%02d" (nth 4 decoded)))
         (day (format "%02d" (nth 3 decoded)))
         (date-str (concat year month day))
         ;; 1. 음력 데이터 가져오기 (실패해도 진행)
         (lunar (condition-case nil (kasi-get-lunar-date year month day) (error nil)))
         ;; 2. 조석 시각 가져오기 (실패해도 진행)
         (tide-times (condition-case nil (nokdong-tide-fetch-tide-times date-str) (error nil)))
         (muldae-str " (물때 정보 없음)")
         (tide-string "- 조석 정보 조회 실패"))

    ;; 물때 계산 (음력이 있을 때만)
    (when lunar
      (let ((muldae (hy/calculate-muldae (plist-get lunar :day))))
        (setq muldae-str (format " (%s)" (if (zerop muldae) "조금" (format "%d물" muldae))))))
    
    ;; 조석 시각 포맷팅 (조석 정보가 있을 때만)
    (when tide-times
      (let ((high (if (string-empty-p (car tide-times)) "정보 없음" (car tide-times)))
            (low (if (string-empty-p (cdr tide-times)) "정보 없음" (cdr tide-times))))
        (setq tide-string (format "- 간조: %s\n- 만조: %s" low high))))

    (cons tide-string muldae-str)))

;; ======================================
;;; Weather Functions
;; ======================================
(defun hy/--format-weather-inline (dom)
  "Extract and format weather for inline display in date line."
  (when-let* ((weekly-forecast (dom-by-class dom "week_item"))
              (day (car weekly-forecast))
              (weather-elem (car (dom-by-class day "weather")))
              (weather-raw (dom-texts weather-elem))
              (weather-normalized (string-trim (replace-regexp-in-string "\\s+" " " weather-raw)))
              (lowest-elem (car (dom-by-class day "lowest")))
              (highest-elem (car (dom-by-class day "highest")))
              (lowest (string-trim (string-replace "최저기온" "" (dom-texts lowest-elem))))
              (highest (string-trim (string-replace "최고기온" "" (dom-texts highest-elem)))))
    
    (let* ((yesterday-day (nth 1 weekly-forecast))
           (yesterday-highest-elem (car (dom-by-class yesterday-day "highest")))
           (yesterday-high (if yesterday-highest-elem
                               (string-to-number 
                                (string-trim (string-replace "최고기온" "" (dom-texts yesterday-highest-elem))))
                             (string-to-number highest)))
           (today-high (string-to-number highest))
           (temp-diff (- today-high yesterday-high))
           (comparison (cond
                        ((> temp-diff 0) (format "%d° 높아요" temp-diff))
                        ((< temp-diff 0) (format "%d° 낮아요" (abs temp-diff)))
                        (t "어제와 같아요"))))
      (format hy-weather-format-template weather-normalized lowest highest comparison))))

(defun hy/--format-weekly-weather (dom)
  "Extract and format weekly weather forecast from DOM."
  (when-let* ((weekly-forecast (dom-by-class dom "week_item"))
              (weekly-data (mapcar 
                            (lambda (day)
                              (let* ((date (string-trim (dom-texts (dom-by-class day "date"))))
                                     (weather-raw (string-trim (dom-texts (dom-by-class day "weather"))))
                                     (weather (replace-regexp-in-string "\\s+" " " weather-raw))
                                     (lowest (string-trim (string-replace "최저기온" "" 
                                                                          (dom-texts (dom-by-class day "lowest")))))
                                     (highest (string-trim (string-replace "최고기온" "" 
                                                                           (dom-texts (dom-by-class day "highest"))))))
                                (format "- %s: %s, 최저/최고 %s/%s" date weather lowest highest)))
                            (seq-take (cdr weekly-forecast) 4))))
    (string-join weekly-data "\n")))

(defun hy/--get-weather-info-sync ()
  "Get weather info synchronously with caching (5-minute cache).
Returns (TODAY-WEATHER . WEEKLY-WEATHER) cons cell."
  (let ((current-time (float-time)))
    (if (and hy/--weather-cache
             (< (- current-time (car hy/--weather-cache)) 300))
        (cdr hy/--weather-cache)
      (when-let ((buffer (hy/--fetch-url-with-timeout
                          (format "https://search.naver.com/search.naver?where=nexearch&sm=top_hty&fbm=0&ie=utf8&query=%s%%20날씨"
                                  (url-hexify-string hy-weather-location))
                          3)))
        (unwind-protect
            (with-current-buffer buffer
              (goto-char (point-min))
              (when (re-search-forward "^$" nil t)
                (let* ((dom (libxml-parse-html-region (point) (point-max)))
                       (today-str (hy/--format-weather-inline dom))
                       (weekly-str (hy/--format-weekly-weather dom))
                       (result (cons today-str weekly-str)))
                  (when (and today-str weekly-str)
                    (setq hy/--weather-cache (cons current-time result))
                    result))))
          (when (buffer-live-p buffer)
            (kill-buffer buffer)))))))

;; ======================================
;;; Helper Functions
;; ======================================
(defun get-random-quote-from-creading ()
  "Extract a random quote from cReading.org file."
  (unless (file-exists-p hy/f-read)
    (error "cReading.org not found at %s" hy/f-read))
  (with-temp-buffer
    (insert-file-contents hy/f-read)
    (let (quotes)
      (goto-char (point-min))
      (while (re-search-forward "^\\* \\(.+\\)" nil t)
        (let* ((title (match-string 1))
               (start (point))
               (end (save-excursion
                      (if (re-search-forward "^\\* " nil t)
                          (match-beginning 0)
                        (point-max))))
               (content (string-trim (buffer-substring-no-properties start end))))
          (push (cons title content) quotes)))
      (if quotes
          (let* ((quote (nth (random (length quotes)) quotes))
                 (raw-result (format "%s\n%s" (car quote) (cdr quote))))
            (string-trim-right raw-result "[ \t\n*]+"))
        "No quotes found in cReading.org"))))

(defun hy/format-agenda-string ()
  "Get formatted 3-day agenda with bullets, removing trailing empty lines."
  (with-temp-buffer
    (org-agenda-list 5)
    (goto-char (point-min))
    (forward-line 1)
    (beginning-of-line)
    (let ((content (buffer-substring-no-properties (point) (point-max))))
      (replace-regexp-in-string "^" "- " (string-trim-right content)))))

;; ======================================
;;; Main Function
;; ======================================
(defun hy/todays-pop ()
  "Display today's and tomorrow's info in a popup buffer."
  (interactive)
  (let* ((start-time (current-time))
         (buffer (get-buffer-create "*Today info*"))
         (current-date (format-time-string "● 오늘: %Y-%m-%d (%a) /"))
         (lunar-date (hy/lunar-date-string))
         (weather-data (hy/--get-weather-info-sync))
         (today-weather (when weather-data (car weather-data)))
         (weekly-weather (when weather-data (cdr weather-data)))
         (tide-today (hy/format-tide-info 0))
         (tide-tomorrow (hy/format-tide-info 1))
         (agenda (hy/format-agenda-string))
         (quote (get-random-quote-from-creading))
         (indent-4 "    ")
         (indent-8 "        "))

    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        
        ;; Header
        (insert indent-8 (hy/emacs-copyright) "\n\n")
        
        ;; Date
        (insert indent-4 current-date lunar-date "\n")
        
        ;; Weather Section
        (when (and today-weather weekly-weather)
          (insert (format "%s● 날씨: %s\n" indent-4 hy-weather-location))
          (insert indent-8 today-weather "\n")
          (insert (replace-regexp-in-string "^" indent-8 weekly-weather)))
        
        ;; Tide Section (Today & Tomorrow)
        (insert (format "\n%s● 조석 (오늘): %s\n" indent-4 
                        (substring (cdr tide-today) 2 -1)))
        (insert (replace-regexp-in-string "^" indent-8 (car tide-today)))
        
        (insert (format "\n%s● 조석 (내일): %s\n" indent-4 
                        (substring (cdr tide-tomorrow) 2 -1)))
        (insert (replace-regexp-in-string "^" indent-8 (car tide-tomorrow)))
        
        ;; Agenda
        (insert (format "\n%s● 일정\n" indent-4))
        (insert (replace-regexp-in-string "^" indent-8 agenda))
        
        ;; Quote
        (insert (format "\n%s● 글말: " indent-4))
        (let* ((quote-lines (split-string quote "\n"))
               (title (car quote-lines))
               (content-lines (cdr quote-lines)))
          (insert (format "%s\n" (or title "")))
          (when content-lines
            (dolist (line content-lines)
              (let ((trimmed (string-trim line)))
                (unless (string-empty-p trimmed)
                  (let ((formatted-line (if (string-prefix-p "-" trimmed)
                                            trimmed
                                          (concat "- " trimmed))))
                    (insert (format "%s%s\n" indent-8 formatted-line))))))))
        
        ;; Setup buffer
        (goto-char (point-min))
        (forward-line 1)
        (beginning-of-line)
        
        (let ((map (make-sparse-keymap)))
          (set-keymap-parent map (current-local-map))
          (define-key map (kbd "q") 
            (lambda () (interactive) (kill-this-buffer)))
          (use-local-map map))))

    (message "Today's info loaded in %.2f seconds"
             (float-time (time-subtract (current-time) start-time)))
    
    (switch-to-buffer buffer)))


;; ======================================
;;; Standalone Commands
;; ======================================
(defun hy/show-lunar-date ()
  "음력 날짜와 물때를 미니버퍼에 표시합니다."
  (interactive)
  (let* ((tide-info (hy/format-tide-info 0))
         (lunar-str (hy/lunar-date-string))
         (muldae-str (cdr tide-info)))
    (message "%s %s" lunar-str muldae-str)))


(defun hy/show-tide-info ()
  "오늘과 내일의 조석 정보를 별도 버퍼에 표시합니다."
  (interactive)
  (let* ((tide-today (hy/format-tide-info 0))
         (tide-tomorrow (hy/format-tide-info 1))
         (buffer (get-buffer-create "*Tide Info*")))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "● 조석 (오늘): %s\n" (substring (cdr tide-today) 2 -1)))
        (insert (car tide-today))
        (insert (format "\n\n● 조석 (내일): %s\n" (substring (cdr tide-tomorrow) 2 -1)))
        (insert (car tide-tomorrow))
        (goto-char (point-min))
        (let ((map (make-sparse-keymap)))
          (set-keymap-parent map (current-local-map))
          (define-key map (kbd "q")
            (lambda () (interactive) (kill-this-buffer)))
          (use-local-map map))))
    (switch-to-buffer buffer)))


(defun hy/show-random-quote ()
  "글말(cReading.org)에서 무작위 인용문을 별도 버퍼에 표시합니다."
  (interactive)
  (let* ((quote (get-random-quote-from-creading))
         (buffer (get-buffer-create "*Random Quote*")))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "● 글말\n\n")
        (let* ((lines (split-string quote "\n"))
               (title (car lines))
               (content-lines (cdr lines)))
          (insert (format "  %s\n" title))
          (dolist (line content-lines)
            (let ((trimmed (string-trim line)))
              (unless (string-empty-p trimmed)
                (insert (format "  %s\n"
                                (if (string-prefix-p "-" trimmed)
                                    trimmed
                                  (concat "- " trimmed))))))))
        (goto-char (point-min))
        (let ((map (make-sparse-keymap)))
          (set-keymap-parent map (current-local-map))
          (define-key map (kbd "q")
            (lambda () (interactive) (kill-this-buffer)))
          (define-key map (kbd "r")
            (lambda () (interactive) (hy/show-random-quote)))
          (use-local-map map))))
    (switch-to-buffer buffer)))


(defun hy/show-weather ()
  "날씨 정보를 별도 버퍼에 표시합니다."
  (interactive)
  (let* ((weather-data (hy/--get-weather-info-sync))
         (buffer (get-buffer-create "*Weather Info*")))
    (if (not weather-data)
        (message "날씨 정보를 가져오지 못했습니다.")
      (with-current-buffer buffer
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (format "● 날씨: %s\n\n" hy-weather-location))
          (insert (format "  %s\n" (car weather-data)))
          (insert "\n")
          (insert (replace-regexp-in-string "^" "  " (cdr weather-data)))
          (insert "\n")
          (goto-char (point-min))
          (let ((map (make-sparse-keymap)))
          (set-keymap-parent map (current-local-map))
            (define-key map (kbd "q")
              (lambda () (interactive) (kill-this-buffer)))
            (define-key map (kbd "r")
              (lambda () (interactive)
                (setq hy/--weather-cache nil)
                (hy/show-weather)))
            (use-local-map map))))
      (switch-to-buffer buffer))))

(provide 'hy-todays-pop)
;;; hy-todays-pop.el ends here
