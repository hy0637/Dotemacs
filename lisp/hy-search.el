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
    ("Emacs Config"   . "~/Project/Dotemacs/"))
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
  "Search file names using fd (NFD-safe on macOS) with Consult UI & Preview.
PDF files are excluded from Emacs buffer preview and open only in macOS Preview app."
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
      (let* ((orig-state (consult--file-state))
             ;; PDF 파일 위에 커서가 올라갔을 때는 Emacs 내부 미리보기를 원천 차단하는 커스텀 스테이트 정의
             (custom-state (lambda (action candidate)
                             (unless (and candidate (string-match-p "\\.pdf\\'" candidate))
                               (funcall orig-state action candidate))))
             (selected (consult--read
                        results
                        :prompt (format "파일 선택 [%s]: " query)
                        :sort nil
                        :category 'file
                        :state custom-state))) ;; 커스텀 스테이트 적용
        (when selected
          (if (string-match-p "\\.pdf\\'" selected)
              ;; 엔터를 치면 오직 mac 시스템 open 명령어로만 실행 (macOS 미리보기)
              (call-process "open" nil 0 nil selected)
            (find-file selected)))))))


(defun hy/rga-skim-search (&optional query)
  "Search PDF contents using `rga` and open in Skim.
Dependency:
  - ripgrep-all (`brew install ripgrep-all`)
  - poppler (`brew install poppler`) : pdftotext 지원용"
  (interactive)
  (let* ((pdf-target (assoc "PDF Files" hy/search-path-targets))
         (pdf-dir (expand-file-name (cdr pdf-target)))
         (default-directory pdf-dir)
         (search-term (or query (read-string "Search PDFs: ")))
         (results (ignore-errors (process-lines "rga" "-l" search-term "."))))
    
    (if (null results)
        (message "결과 없음: '%s' (rga 또는 brew install poppler 설치 여부 확인)" search-term)
      (catch 'exit
        (while t
          (let ((selected-file
                 (condition-case nil
                     (completing-read (format "파일 선택 [%s]: " search-term) results nil t)
                   (quit (throw 'exit nil)))))
            (condition-case nil
                (let* ((full-path (expand-file-name selected-file default-directory))
                       (lines (ignore-errors (process-lines "rga" "-n" search-term full-path)))
                       (selected-line (completing-read "결과 내 이동 (C-g=뒤로): " lines nil t))
                       (page-num (when (and selected-line (string-match "Page \\([0-9]+\\)" selected-line))
                                   (string-to-number (match-string 1 selected-line)))))
                  
                  (kill-new search-term)
                  (if page-num
                      (do-applescript
                       (format "tell application \"Skim\"
                                     activate
                                     open POSIX file \"%s\"
                                     tell front document to go to page %d
                                end tell" full-path page-num))
                    (call-process "open" nil 0 nil full-path))
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


;; ======================================
;;; Transient Dispatcher
;; ======================================

;;;###autoload
(defun hy/search-dwim ()
  "검색 대기 모드 (C-c s)

   [u / s] 통합 검색 (웹/로컬)
   [f / n] 파일명 검색 (fd)
   [p / r] PDF 본문 검색 (rga + Skim)
   [d]     macOS 사전 검색"
  (interactive)
  (message "검색 모드: [u/s]통합검색 | [f/n]파일명 | [p/r]PDF본문 | [d]사전 (종료: 다른키)")
  (set-transient-map
   (let ((map (make-sparse-keymap)))
     ;; 1. 통합 검색 (Unified Search)
     (define-key map (kbd "u") #'hy/search-unified)
     (define-key map (kbd "s") #'hy/search-unified)

     ;; 2. 파일명 검색 (Filename Search)
     (define-key map (kbd "f") (lambda () (interactive) (call-interactively #'hy/fd-filename-search)))
     (define-key map (kbd "n") (lambda () (interactive) (call-interactively #'hy/fd-filename-search)))

     ;; 3. PDF 본문 검색 (RGA + Skim)
     (define-key map (kbd "p") #'hy/rga-skim-search)
     (define-key map (kbd "r") #'hy/rga-skim-search)

     ;; 4. macOS 사전 단독 검색
     (define-key map (kbd "d") (lambda () 
                                 (interactive) 
                                 (let ((word (read-string "사전 검색: " (thing-at-point 'symbol t))))
                                   (hy--open-url (hy/get-search-url "macOS Dictionary" word)))))
     map)))

(provide 'hy-search)
;;; hy-search.el ends here
