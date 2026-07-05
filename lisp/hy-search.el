;;; hy-search.el --- Web search and local file search unified -*- lexical-binding: t; -*-

(require 'url)
(require 'dom)
(require 'cl-lib)
(require 'consult)
(require 'ucs-normalize)

;; ======================================
;;; Configuration
;; ======================================

(defvar hy/search-engines
  '(("macOS Dictionary" . dict)
    ("Naver" .  "https://search.naver.com/search.naver?query=%s")
    ("Naver Hanja" . "https://hanja.dict.naver.com/#/search?range=all&query=%s")
    ("Google" . "https://www.google.com/search?q=%s")
    ("Filename Search" . filename))
  "List of web search engines (Name . URL/Type).")

(defvar hy/search-path-targets
  '(("Docs (All)"     . "~/Dropbox/Docs/")
    ("Org Files"      . "~/Dropbox/Docs/org/")
    ("PDF Files"      . "~/Dropbox/Docs/pdf/") 
    ("Notes/Person"   . "~/Dropbox/Docs/Person/")
    ("Denote"         . "~/Dropbox/Docs/org/denote/")
    ("Emacs Config"   . "~/Project/Dotemacs/")) ; 수정된 Emacs 설정 디렉토리 반영
  "List of local directories for ripgrep search.")


;; ======================================
;;; Helper Functions
;; ======================================

(defun hy/get-search-url (engine query)
  "Generate a search URL from a search engine and a query."
  (let ((config (assoc engine hy/search-engines)))
    (when config
      (let ((url-template (cdr config)))
        (if (eq url-template 'dict)
            (concat "dict://" (url-hexify-string query))
          (format url-template (url-hexify-string query)))))))

(defun hy--open-url (url)
  "Open URL in the default web browser or macOS Dictionary."
  (if (string-prefix-p "dict://" url)
      (call-process "open" nil 0 nil url)
    (browse-url url)))


(defun hy/fd-filename-search (query)
  "Search file names using fd (NFD-safe on macOS) with Consult UI and Preview."
  (interactive "s검색어: ")
  (let* ((path-choice (completing-read "Search in: "
                                       (mapcar #'car hy/search-path-targets)
                                       nil t))
         (search-dir  (expand-file-name
                       (cdr (assoc path-choice hy/search-path-targets))))
         ;; Dropbox 환경 대응을 위해 검색어를 NFD로 완전 변환
         (query-nfd   (ucs-normalize-NFD-string query))
         ;; shell 호출 대신 process-lines로 안전하게 리스트 추출
         (coding-system-for-read 'utf-8-hfs)
         (results     (process-lines "fd" "--color=never" "--hidden" "--path-separator=/" query-nfd search-dir)))
    (if (null results)
        (message "결과 없음: '%s'" query)
      (let ((selected (consult--read
                       results
                       :prompt (format "파일 선택 [%s]: " query)
                       :sort nil
                       :category 'file
                       :state (consult--file-state))))
        (when selected
          (if (string-match-p "\\.pdf\\'" selected)
              (call-process "open" nil 0 nil selected)
            (find-file selected)))))))


(defun hy/rga-skim-search (&optional query)
  "Search PDF contents using `rga` and open in Skim."
  (interactive)
  (let* ((pdf-target (assoc "PDF Files" hy/search-path-targets))
         (default-directory (expand-file-name (cdr pdf-target)))
         (search-term (or query (read-string "Search PDFs: ")))
         ;; 쉘 파이프라인 에러 방지를 위해 process-lines 활용
         (results (process-lines "rga" "-l" search-term ".")))
    (if (null results)
        (message "결과 없음: '%s'" search-term)
      (catch 'exit
        (while t
          (let ((selected-file
                 (condition-case nil
                     (completing-read (format "파일 선택 [%s]: " search-term) results nil t)
                   (quit (throw 'exit nil)))))
            (condition-case nil
                (let* ((full-path (expand-file-name selected-file default-directory))
                       ;; 개별 파일 내부 줄 검색
                       (lines (process-lines "rga" "-n" search-term full-path))
                       (selected-line (completing-read "결과 내 이동 (C-g=뒤로): " lines nil t)))
                  (kill-new search-term)
                  (let ((page-num (when (string-match "Page \\([0-9]+\\)" selected-line)
                                    (string-to-number (match-string 1 selected-line)))))
                    (if page-num
                        (do-applescript
                         (format "tell application \"Skim\"
                                       activate
                                       open POSIX file \"%s\"
                                       tell front document to go to page %d
                                  end tell" full-path page-num))
                      (call-process "open" nil 0 nil full-path)))
                  (throw 'exit nil))
              (quit (message "파일 목록으로 복귀")))))))))


;; ======================================
;;; Main Function
;; ======================================

;;; ###autoload
(defun hy/search-unified (&optional query)
  "Unified search interface for Web and Local files.
Select between Web engines or Local paths for the given QUERY."
  (interactive 
   (list (let ((input (read-string "Search query: " (thing-at-point 'symbol t))))
           (if (string-empty-p input) (thing-at-point 'symbol t) input))))
  
  ;; 빈 문자열("")이 들어올 경우 처리 보완
  (let* ((search-term (if (or (null query) (string-empty-p query))
                          (or (thing-at-point 'symbol t) "")
                        query))
         (web-options (mapcar #'car hy/search-engines))
         (local-options (mapcar #'car hy/search-path-targets))
         (all-options (append web-options local-options))
         (choice (completing-read (format "Search '%s' in: " search-term) all-options))
         (web-config (assoc choice hy/search-engines))
         (local-path (cdr (assoc choice hy/search-path-targets))))
    
    (if (string-empty-p search-term)
        (message "검색어가 입력되지 않았습니다.")
      (cond
       ;; CASE 1: Filename Search (fd 기반 NFD-safe)
       ((and web-config (eq (cdr web-config) 'filename))
        (hy/fd-filename-search search-term))

       ;; CASE 2: Web Engine Selection
       (web-config
        (let ((url (hy/get-search-url choice search-term)))
          (if (and url (not (string-empty-p url)))
              (hy--open-url url)
            (message "Invalid URL configuration."))))
       
       ;; CASE 3: Local PDF Path Selection
       ((and local-path (string-match-p "PDF" choice))
        (hy/rga-skim-search search-term))
       
       ;; CASE 4: Standard Local Path Selection (Consult-ripgrep 연동 최적화)
       (local-path
        (let ((default-directory (expand-file-name local-path)))
          ;; 첫 검색어가 미니버퍼에 실시간 매칭되도록 주입하는 최적 방식
          (consult-ripgrep default-directory search-term)))))))


;; ======================================
;;; Embark Integration
;; ======================================

(with-eval-after-load 'embark
  (let ((target-maps (list embark-identifier-map embark-region-map)))
    (dolist (map target-maps)
      (define-key map (kbd "S") #'hy/search-unified))))

(provide 'hy-search)
;;; hy-search.el ends here
