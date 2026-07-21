;;; hy-pairs.el --- configuration -*- lexical-binding: t; -*-

;;; ver20260719

;;; CODE;

;; =======================================
;;; pair-pair-wrap (통합: 일반 기호 + 한자 병기)
;; =======================================
;; inspire https://protesilaos.com
(require 'cl-lib)

(defcustom hy/pair-pairs
  '((?* :description "Bold"           :pair ?*)
    (?/ :description "Italic"         :pair ?/)
    (?= :description "Verbatim"       :pair ?=)
    (?~ :description "Code"           :pair ?~)
    (?+ :description "Strike"         :pair ?+)
    (?_ :description "Under Line"     :pair ?_)
    (?\" :description "“ ”"           :pair ("“" . "”"))
    (?\' :description "‘’"            :pair ("‘" . "’"))
    (?m  :description "Em-dash"       :pair ("— " . " —"))
    (?-  :description "Hyphen-"       :pair ("- " . " -"))
    (?\( :description " () "          :pair (?\( . ?\)))
    (?\[ :description " [] "          :pair (?\[ . ?\]))
    (?{  :description " {} "          :pair (?{ . ?}))
    (?,  :description " <> "          :pair (?< . ?>))
    (?<  :description " 「」 "         :pair ("「" . "」"))
    (?>  :description " 『』 "         :pair ("『" . "』"))
    (?M  :description " 《》 "         :pair ("《" . "》")))
  "List of Org-mode emphasis markers and special bracket pairs."
  :group 'editing
  :type '(alist :key-type character :value-type (plist)))

;; ---------------------------------------
;; 내부 보조 함수
;; ---------------------------------------
(defun hy/region-or-buffer ()
  "Return (BEG END) of the active region, or of the whole buffer."
  (if (use-region-p)
      (list (region-beginning) (region-end))
    (list (point-min) (point-max))))

(defun hy/pair--strings (char)
  "Return the (OPEN . CLOSE) string pair registered for CHAR, or nil."
  (let ((pd (plist-get (cdr (assoc char hy/pair-pairs)) :pair)))
    (when pd
      (if (consp pd)
          (cons (if (characterp (car pd)) (char-to-string (car pd)) (car pd))
                (if (characterp (cdr pd)) (char-to-string (cdr pd)) (cdr pd)))
        (let ((s (char-to-string pd))) (cons s s))))))

(defun hy/pair--process-range (beg end open-str close-str content-regexp mode)
  "BEG..END 범위에서 OPEN-STR CONTENT-REGEXP CLOSE-STR 패턴을 모두 찾아
MODE에 따라 처리하고, 처리한 개수를 반환.
MODE가 'strip: 괄호(기호)만 벗기고 내용은 남기고,
MODE가 'erase: 괄호(기호)+내용을 통째로 삭제합니다."
  (let* ((pattern (concat (regexp-quote open-str)
                           "\\(" content-regexp "\\)"
                           (regexp-quote close-str)))
         (count 0)
         (end-marker (copy-marker end)))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward pattern end-marker t)
        (pcase mode
          ('strip (replace-match "\\1" t))
          ('erase (replace-match "" t t)))
        (setq count (1+ count))))
    (set-marker end-marker nil)
    count))

;; ---------------------------------------
;; 일반 기호: Wrap (독립 명령 — 메뉴 없이 즉시 실행)
;; ---------------------------------------
(defun hy/pair-wrap ()
  "일반 쌍 기호로 region(또는 word at point)을 즉시 감쌈.
메뉴 없이 기호 입력만으로 바로 실행.
hy/pair-manage의 [1] Wrap 분기에서도 이 함수 그대로 호출."
  (interactive)
  (let* ((char (read-char "기호 입력 (*, /, =, (, <...): "))
         (entry (assoc char hy/pair-pairs))
         (pair-data (plist-get (cdr entry) :pair))
         (open      (if (consp pair-data) (car pair-data) pair-data))
         (close     (if (consp pair-data) (cdr pair-data) pair-data))
         (open-str  (if (characterp open)  (char-to-string open)  open))
         (close-str (if (characterp close) (char-to-string close) close)))
    (if (not pair-data)
        (message "Undefined symbol: %c" char)
      (if (not (use-region-p))
          ;; region 없음: word at point 감싸기
          (let* ((bounds (or (bounds-of-thing-at-point 'symbol)
                             (cons (point) (point))))
                 (start (car bounds))
                 (wend  (cdr bounds)))
            (save-excursion
              (goto-char wend)  (insert close-str)
              (goto-char start) (insert open-str)))
        ;; region 있음: 가장자리 기존 기호 감지 후 치환
        (let* ((rbeg (region-beginning))
               (rend (region-end))
               (all-pairs
                (apply #'append
                       (mapcar (lambda (e)
                                 (let* ((key (car e))
                                        (pd  (plist-get (cdr e) :pair)))
                                   (when (consp pd)
                                     (let* ((os (if (characterp (car pd))
                                                    (char-to-string (car pd))
                                                  (car pd)))
                                            (cs (if (characterp (cdr pd))
                                                    (char-to-string (cdr pd))
                                                  (cdr pd)))
                                            (key-str (char-to-string key)))
                                       (list (cons os cs)
                                             (cons key-str cs)
                                             (cons os key-str)
                                             (cons key-str key-str))))))
                               hy/pair-pairs)))
               (existing-open
                (cl-some (lambda (p)
                           (let ((os (car p)))
                             (when (string= os (buffer-substring-no-properties
                                                rbeg (min (+ rbeg (length os)) rend)))
                               os)))
                         all-pairs))
               (existing-close
                (cl-some (lambda (p)
                           (let ((cs (cdr p)))
                             (when (string= cs (buffer-substring-no-properties
                                                (max (- rend (length cs)) rbeg) rend))
                               cs)))
                         all-pairs))
               (open-len  (length (or existing-open  "")))
               (close-len (length (or existing-close ""))))
          (save-excursion
            (if existing-close
                (progn (goto-char (- rend close-len))
                       (delete-char close-len)
                       (insert close-str))
              (goto-char rend)
              (insert close-str))
            (if existing-open
                (progn (goto-char rbeg)
                       (delete-char open-len)
                       (insert open-str))
              (goto-char rbeg)
              (insert open-str)))
          (message "'%s' 감싸기 완료" (plist-get (cdr entry) :description)))))))

;; ---------------------------------------
;; 한자 병기: Wrap 전용 로직
;; ---------------------------------------
(defun hy/pair--wrap-hanja (beg end)
  "BEG..END 범위 내 모든 漢字 뭉치를 괄호로 감쌈."
  (let ((count 0)
        (end-marker (copy-marker end)))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward "[一-鿿]+" end-marker t)
        (let ((match-beg (match-beginning 0))
              (match-end (match-end 0)))
          (unless (and (eq (char-before match-beg) ?\()
                       (eq (char-after match-end) ?\)))
            (let ((hanja (match-string 0)))
              (replace-match (concat "(" hanja ")") t t))
            (setq count (1+ count))))))
    (set-marker end-marker nil)
    (message "漢字 괄호 감싸기 %d곳 완료" count)))

;; ---------------------------------------
;; 2단계(1/2/3/4) 공용 디스패처
;; ---------------------------------------
(cl-defun hy/pair--dispatch-action (beg end &key open-close-reader content-regexp wrap-fn swap-reverse-p)
  "[1]Wrap / [2]Strip / [3]Erase / [4]Swap 중 선택하여 실행하는 공용 2단계 로직.
SWAP-REVERSE-P가 t이면 역방향(漢字(한글)->한글(漢字))으로 swap 시도."
  (let ((choice (read-char-from-minibuffer
                 "선택 [1] 감싸기(Wrap)  [2] 벗기기(Strip)  [3] 내용째 삭제(Erase)  [4] 漢字한글 Swap: ")))
    (cond
     ((eq choice ?1)
      (funcall wrap-fn beg end))
     ((eq choice ?2)
      (let ((pair (funcall open-close-reader)))
        (if (not pair)
            (message "정의되지 않은 기호입니다.")
          (message "'%s…%s' 기호 %d곳 벗김" (car pair) (cdr pair)
                   (hy/pair--process-range beg end (car pair) (cdr pair)
                                           content-regexp 'strip)))))
     ((eq choice ?3)
      (let ((pair (funcall open-close-reader)))
        (if (not pair)
            (message "정의되지 않은 기호입니다.")
          (message "'%s…%s' 내용 포함 %d곳 제거" (car pair) (cdr pair)
                   (hy/pair--process-range beg end (car pair) (cdr pair)
                                           content-regexp 'erase)))))
     ((eq choice ?4)
      ;; 한글/한자 순서 뒤집기 실행
      (let* ((pattern (if swap-reverse-p
                          "\\([一-鿿]+\\)(\\([가-힣]+\\))"   ; 한자(한글)
                        "\\([가-힣]+\\)(\\([一-鿿]+\\))"))   ; 한글(한자)
             (count 0)
             (end-marker (copy-marker end)))
        (save-excursion
          (goto-char beg)
          (while (re-search-forward pattern end-marker t)
            (replace-match "\\2(\\1)" t)
            (setq count (1+ count))))
        (set-marker end-marker nil)
        (message "%d곳 순서 변환 완료 (%s)"
                 count
                 (if swap-reverse-p "漢字(한글) → 한글(漢字)" "한글(漢字) → 漢字(한글)"))))
     (t (message "취소되었습니다.")))))

;; ---------------------------------------
;; 통합 진입점: 漢字/일반(C-u) + 1/2/3/4 Action
;; ---------------------------------------
;;;###autoload
(defun hy/pair-manage (beg end &optional alt-mode)
  "쌍 기호, 한자 괄호 감싸기 및 한글/漢字 병기 순서 교체(Swap) 통합 관리.
기본 실행: '漢字 병기 및 정방향 Swap' 관리 모드로 진입.
\\[universal-argument] (C-u) 접두사: '일반 기호 및 역방향 Swap' 관리 모드로 진입."
  (interactive
   (append
    (if (use-region-p)
        (list (region-beginning) (region-end))
      (list (point-min) (point-max)))
    (list current-prefix-arg)))
  
  (let ((target (if alt-mode ?g ?h)))
    (pcase target
      (?h (hy/pair--dispatch-action
           beg end
           :open-close-reader (lambda () (cons "(" ")"))
           :content-regexp "[一-鿿]+"
           :wrap-fn #'hy/pair--wrap-hanja
           :swap-reverse-p nil)) ;; 기본 실행 시 정방향 Swap 매칭
      (?g (hy/pair--dispatch-action
           beg end
           :open-close-reader (lambda ()
                                (hy/pair--strings
                                 (read-char "기호 입력 (*, (, <, M...): ")))
           :content-regexp "\\(?:.\\|\n\\)*?"
           :wrap-fn (lambda (_beg _end) (hy/pair-wrap))
           :swap-reverse-p t))) ;; C-u 실행 시 역방향 Swap 매칭
    (when (use-region-p)
      (setq deactivate-mark nil))))



(provide 'hy-pairs)
;;; hy-pairs.el ends here
