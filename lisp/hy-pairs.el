;;; hy-pairs.el --- configuration -*- lexical-binding: t; -*-

;;; 20260705 Created by HY

;;; CODE;


;; =======================================
;;; pair-pair-wrap
;; =======================================
;; inspire https://protesilaos.com
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

;; 공용 헬퍼: OPEN-STR...CLOSE-STR로 둘러싸인 대상을 범위 내에서 찾아 벗기거나(strip) 통째로 삭제(erase)
;; 한자 병기와 pair-pairs가 공유하는 핵심 로직. 차이는 CONTENT-REGEXP(내용 패턴)뿐.
(defun hy/pair--process-range (beg end open-str close-str content-regexp mode)
  "BEG..END 범위에서 OPEN-STR CONTENT-REGEXP CLOSE-STR 패턴을 모두 찾아
MODE에 따라 처리하고, 처리한 개수를 반환합니다.
MODE가 'strip 이면 괄호(기호)만 벗기고 내용은 남기고,
MODE가 'erase 이면 괄호(기호)+내용을 통째로 삭제합니다."
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

(defun hy/pair--unwrap-edges (rbeg rend)
  "Remove a registered pair found at the edges of RBEG..REND.
Return t if a pair was removed, nil otherwise."
  (catch 'done
    (dolist (e hy/pair-pairs)
      (let ((p (hy/pair--strings (car e))))
        (when p
          (let ((ol (length (car p))) (cl (length (cdr p))))
            (when (and (>= (- rend rbeg) (+ ol cl))
                       (string= (car p)
                                (buffer-substring-no-properties rbeg (+ rbeg ol)))
                       (string= (cdr p)
                                (buffer-substring-no-properties (- rend cl) rend)))
              (save-excursion
                (goto-char (- rend cl)) (delete-char cl)
                (goto-char rbeg)        (delete-char ol))
              (message "'%s%s' 제거 완료" (car p) (cdr p))
              (throw 'done t))))))
    nil))

;; ---------------------------------------
;; 사용자 명령
;; ---------------------------------------
(defun hy/pair-pairs-wrap (beg end)
  "쌍 기호(pair) 관리: 감싸기 / 벗기기 / 내용째 제거를 선택하여 실행합니다.
범위(region)가 지정되어 있으면 그 범위 내에서, 지정되어 있지 않으면
버퍼 전체를 대상으로 동작합니다.

[1] Wrap:  word/region   -> *word*      (기호로 감싸기)
[2] Strip: *내용*...      -> 내용...     (범위 내 모든 짝의 기호만 벗기기)
[3] Erase: *내용*...      -> ...         (범위 내 모든 짝을 기호+내용째 삭제)"
  (interactive
   (if (use-region-p)
       (list (region-beginning) (region-end))
     (list (point-min) (point-max))))
  (let ((choice (read-char-from-minibuffer
                 "선택 [1] 감싸기(Wrap)  [2] 벗기기(Strip)  [3] 내용째 삭제(Erase): ")))
    (cond
     ;; -------------------------------------------------------------
     ;; [1] 감싸기: region이 있으면 region을, 없으면 word at point를 감싼다
     ;; -------------------------------------------------------------
     ((eq choice ?1)
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

     ;; -------------------------------------------------------------
     ;; [2] 벗기기: beg..end 범위 내 모든 짝의 기호만 제거 (내용 유지)
     ;; -------------------------------------------------------------
     ((eq choice ?2)
      (let* ((char (read-char "벗길 기호 (*, (, <, M...): "))
             (pair (hy/pair--strings char)))
        (if (not pair)
            (message "Undefined symbol: %c" char)
          (message "'%s…%s' 기호 %d곳 벗김" (car pair) (cdr pair)
                   (hy/pair--process-range beg end (car pair) (cdr pair)
                                           "\\(?:.\\|\n\\)*?" 'strip)))))

     ;; -------------------------------------------------------------
     ;; [3] 내용째 삭제: beg..end 범위 내 모든 짝을 기호+내용 통째로 제거
     ;; -------------------------------------------------------------
     ((eq choice ?3)
      (let* ((char (read-char "내용째 제거할 기호 (*, (, <, M...): "))
             (pair (hy/pair--strings char)))
        (if (not pair)
            (message "Undefined symbol: %c" char)
          (message "'%s…%s' 내용 포함 %d곳 제거" (car pair) (cdr pair)
                   (hy/pair--process-range beg end (car pair) (cdr pair)
                                           "\\(?:.\\|\n\\)*?" 'erase)))))

     (t (message "취소되었습니다.")))
    (when (use-region-p)
      (setq deactivate-mark nil))))


;; (with-eval-after-load 'embark
;;   (dolist (map (list embark-symbol-map
;;                      embark-region-map
;;                      embark-general-map))
;;     (define-key map (kbd "w") #'hy/pair-pairs-wrap)))


;; =======================================
;;; manage Hanja
;; =======================================
;;;###autoload
(defun hy/manage-hanja-annotations (beg end)
  "Manage Hanja annotations in region or whole buffer by choosing an action.
[1] Wrap:  代書   -> (代書)  (괄호 감싸기)
[2] Strip: (代書) -> 代書    (괄호만 벗기기)
[3] Erase: (代書) -> \"\"   (한자 병기 통째로 삭제)"
  (interactive
   (if (use-region-p)
       (list (region-beginning) (region-end))
     (list (point-min) (point-max))))

  (let ((choice (read-char-from-minibuffer "선택 [1] 감싸기(Wrap)  [2] 괄호 벗기기(Strip)  [3] 통째로 삭제(Erase): ")))
    (cond
     ;; -------------------------------------------------------------
     ;; [1번] 한자 -> (한자) 감싸기
     ;; -------------------------------------------------------------
     ((eq choice ?1)
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
        (message "한자 괄호 감싸기 %d곳 완료" count)))

     ;; -------------------------------------------------------------
     ;; [2번] (한자) -> 한자 (괄호만 삭제) — 공용 헬퍼 사용
     ;; -------------------------------------------------------------
     ((eq choice ?2)
      (message "한자 괄호 벗기기 %d곳 완료"
               (hy/pair--process-range beg end "(" ")" "[一-鿿]+" 'strip)))

     ;; -------------------------------------------------------------
     ;; [3번] (한자) -> "" (괄호와 한자 모두 삭제) — 공용 헬퍼 사용
     ;; -------------------------------------------------------------
     ((eq choice ?3)
      (message "한자 병기 %d곳 통째로 삭제 완료"
               (hy/pair--process-range beg end "(" ")" "[一-鿿]+" 'erase)))

     (t
      (message "취소되었습니다.")))
    (when (use-region-p)
      (setq deactivate-mark nil))))


;; end here
(provide 'hy-pairs)
