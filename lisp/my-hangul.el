;; -*- lexical-binding: t -*-
;;  my-hangul.el — 두벌식 한글 입력기
;;  NavilIME Hangul.swift + Keyboard002.swift 직접 포팅
;;
;;  키 배치:
;;   q=ㅂ  w=ㅈ  e=ㄷ  r=ㄱ  t=ㅅ  y=ㅛ  u=ㅕ  i=ㅑ  o=ㅐ  p=ㅔ
;;   a=ㅁ  s=ㄴ  d=ㅇ  f=ㄹ  g=ㅎ  h=ㅗ  j=ㅓ  k=ㅏ  l=ㅣ
;;   z=ㅋ  x=ㅌ  c=ㅊ  v=ㅍ  b=ㅠ  n=ㅜ  m=ㅡ
;;   Q=ㅃ  W=ㅉ  E=ㄸ  R=ㄲ  T=ㅆ(초성/종성)  O=ㅒ  P=ㅖ
;;   연속: qq=ㅃ ww=ㅉ ee=ㄸ rr=ㄲ tt=ㅆ(초성) oo=ㅒ pp=ㅖ tt=ㅆ(종성)

;; 두벌식 한글 입력, 겹받침, 쌍자음
;; oo→ㅒ, pp→ㅖ 연속 모음
;; F9 한자/기호 변환
;; 노란 언더라인 preedit
;; C-g 탈출
;; C-x, C-c, C-h, M-x 입력 시 자동 영문 전환
;; 미니버퍼 한글 입력 가능 (read-string 등)
;; C-x p p 후 명령 선택은 prefix override가 처리
;; 

(require 'quail)
(require 'hanja-util)

;;; ============================================================
;;; 레이아웃 테이블 (Keyboard002.swift 그대로)
;;; ============================================================

(defconst my/hangul-cho-layout
  '(("Q" . #x1108) ("qq" . #x1108)
    ("W" . #x110D) ("ww" . #x110D)
    ("E" . #x1104) ("ee" . #x1104)
    ("R" . #x1101) ("rr" . #x1101)
    ("T" . #x110A) ("tt" . #x110A)
    ("q" . #x1107) ("w" . #x110C) ("e" . #x1103) ("r" . #x1100) ("t" . #x1109)
    ("a" . #x1106) ("A" . #x1106) ("s" . #x1102) ("S" . #x1102)
    ("d" . #x110B) ("D" . #x110B) ("f" . #x1105) ("F" . #x1105)
    ("g" . #x1112) ("G" . #x1112) ("z" . #x110F) ("Z" . #x110F)
    ("x" . #x1110) ("X" . #x1110) ("c" . #x110E) ("C" . #x110E)
    ("v" . #x1111) ("V" . #x1111)))

(defconst my/hangul-jung-layout
  '(("O" . #x1164) ("oo" . #x1164)
    ("P" . #x1168) ("pp" . #x1168)
    ("y" . #x116D) ("Y" . #x116D) ("u" . #x1167) ("U" . #x1167)
    ("i" . #x1163) ("I" . #x1163)
    ("o" . #x1162) ("p" . #x1166)
    ("h" . #x1169) ("H" . #x1169) ("j" . #x1165) ("J" . #x1165)
    ("k" . #x1161) ("K" . #x1161) ("l" . #x1175) ("L" . #x1175)
    ("b" . #x1172) ("B" . #x1172) ("n" . #x116E) ("N" . #x116E)
    ("m" . #x1173) ("M" . #x1173)
    ("hk" . #x116A) ("Hk" . #x116A) ("HK" . #x116A)
    ("ho" . #x116B) ("Ho" . #x116B) ("HO" . #x116B)
    ("nj" . #x116F) ("Nj" . #x116F) ("NJ" . #x116F)
    ("np" . #x1170) ("Np" . #x1170) ("NP" . #x1170)
    ("hl" . #x116C) ("Hl" . #x116C) ("HL" . #x116C)
    ("nl" . #x1171) ("Nl" . #x1171) ("NL" . #x1171)
    ("ml" . #x1174) ("Ml" . #x1174) ("ML" . #x1174)))

(defconst my/hangul-jong-layout
  '(("r"  . #x11A8) ("R"  . #x11A9) ("rr" . #x11A9)
    ("rt" . #x11AA) ("Rt" . #x11AA) ("RT" . #x11AA)
    ("s"  . #x11AB) ("S"  . #x11AB)
    ("sw" . #x11AC) ("Sw" . #x11AC) ("SW" . #x11AC)
    ("sg" . #x11AD) ("Sg" . #x11AD) ("SG" . #x11AD)
    ("e"  . #x11AE) ("E"  . #x11AE)
    ("f"  . #x11AF) ("F"  . #x11AF)
    ("fr" . #x11B0) ("Fr" . #x11B0) ("FR" . #x11B0)
    ("fa" . #x11B1) ("Fa" . #x11B1) ("FA" . #x11B1)
    ("fq" . #x11B2) ("Fq" . #x11B2) ("FQ" . #x11B2)
    ("ft" . #x11B3) ("Ft" . #x11B3) ("FT" . #x11B3)
    ("fx" . #x11B4) ("Fx" . #x11B4) ("FX" . #x11B4)
    ("fv" . #x11B5) ("Fv" . #x11B5) ("FV" . #x11B5)
    ("fg" . #x11B6) ("Fg" . #x11B6) ("FG" . #x11B6)
    ("a"  . #x11B7) ("A"  . #x11B7)
    ("q"  . #x11B8) ("Q"  . #x11B8)
    ("qt" . #x11B9) ("Qt" . #x11B9) ("QT" . #x11B9)
    ("t"  . #x11BA) ("T"  . #x11BB) ("tt" . #x11BB)
    ("d"  . #x11BC) ("D"  . #x11BC)
    ("w"  . #x11BD) ("W"  . #x11BD)
    ("c"  . #x11BE) ("C"  . #x11BE)
    ("z"  . #x11BF) ("Z"  . #x11BF)
    ("x"  . #x11C0) ("X"  . #x11C0)
    ("v"  . #x11C1) ("V"  . #x11C1)
    ("g"  . #x11C2) ("G"  . #x11C2)))

(defconst my/hangul-cho-compat
  '((#x1100 . #x3131) (#x1101 . #x3132) (#x1102 . #x3134)
    (#x1103 . #x3137) (#x1104 . #x3138) (#x1105 . #x3139)
    (#x1106 . #x3141) (#x1107 . #x3142) (#x1108 . #x3143)
    (#x1109 . #x3145) (#x110A . #x3146) (#x110B . #x3147)
    (#x110C . #x3148) (#x110D . #x3149) (#x110E . #x314A)
    (#x110F . #x314B) (#x1110 . #x314C) (#x1111 . #x314D)
    (#x1112 . #x314E)))

;;; ============================================================
;;; 해시테이블 (alist → O(1) 탐색)
;;; ============================================================

(defconst my/hangul-cho-table
  (let ((h (make-hash-table :test 'equal :size 64)))
    (dolist (pair my/hangul-cho-layout h)
      (puthash (car pair) (cdr pair) h))))

(defconst my/hangul-jung-table
  (let ((h (make-hash-table :test 'equal :size 64)))
    (dolist (pair my/hangul-jung-layout h)
      (puthash (car pair) (cdr pair) h))))

(defconst my/hangul-jong-table
  (let ((h (make-hash-table :test 'equal :size 128)))
    (dolist (pair my/hangul-jong-layout h)
      (puthash (car pair) (cdr pair) h))))

(defconst my/hangul-cho-compat-table
  (let ((h (make-hash-table :test 'eql :size 32)))
    (dolist (pair my/hangul-cho-compat h)
      (puthash (car pair) (cdr pair) h))))

;;; ============================================================
;;; 유니코드 조합
;;; ============================================================

(defun my/hangul--norm (cho-k jung-k jong-k)
  "키 문자열 → 유니코드 문자열."
  (let ((cho  (gethash cho-k  my/hangul-cho-table))
        (jung (gethash jung-k my/hangul-jung-table))
        (jong (gethash jong-k my/hangul-jong-table)))
    (cond
     ((and cho jung jong)
      (string (decode-char 'ucs
               (+ #xAC00 (* (- cho #x1100) 21 28)
                  (* (- jung #x1161) 28) (- jong #x11A7)))))
     ((and cho jung)
      (string (decode-char 'ucs
               (+ #xAC00 (* (- cho #x1100) 21 28) (* (- jung #x1161) 28)))))
     (jung (string (decode-char 'ucs jung)))
     (cho  (string (decode-char 'ucs
                    (or (gethash cho my/hangul-cho-compat-table) #x3131))))
     (t ""))))

;;; ============================================================
;;; Automata.run() 포팅
;;; ============================================================

(defun my/hangul--run (current)
  "나빌 Automata.run() 포팅.
CURRENT: 키 문자열 리스트.
반환: (cho jung jong done remaining)"
  (let ((cho "") (jung "") (jong "") (done nil))
    (catch 'exit
      (dolist (ch current)
        (let ((can-cho (and (not (and (not (string= cho ""))
                                     (not (string= jung ""))))
                            (gethash (concat cho ch) my/hangul-cho-table)))
              (in-jung (gethash ch my/hangul-jung-table)))
          (cond
           ;; 초성 가능
           (can-cho
            (cond
             ((string= cho "") (setq cho ch))
             ((string= jung "") (setq cho (concat cho ch))) ; 쌍자음
             (t (setq done t) (throw 'exit nil))))

           ;; 중성 가능 — jungsung_proc 포팅
           (in-jung
            (if (not (string= jong ""))
                ;; 종성 있음: 마지막 글자가 초성 테이블에 있으면 도깨비불
                (let* ((jong-chars (string-to-list jong))
                       (jong-last  (string (car (last jong-chars))))
                       (jong-rest  (apply #'string (butlast jong-chars))))
                  (if (gethash jong-last my/hangul-cho-table)
                      (progn
                        (setq jong jong-rest)
                        (setq done t)
                        (throw 'exit nil))
                    ;; 도깨비불 아님: 이중모음 시도
                    (if (gethash (concat jung ch) my/hangul-jung-table)
                        (setq jung (concat jung ch))
                      (setq done t) (throw 'exit nil))))
              ;; 종성 없음: 이중모음 또는 첫 중성
              (if (gethash (concat jung ch) my/hangul-jung-table)
                  (setq jung (concat jung ch))
                (setq done t) (throw 'exit nil))))

           ;; 종성 가능 — jongsung_proc: 중성 있을 때만
           ((and (not (string= jung ""))
                 (gethash (concat jong ch) my/hangul-jong-table))
            (setq jong (concat jong ch)))

           ;; 허용 안 됨
           (t (setq done t) (throw 'exit nil))))))

    (let* ((size      (+ (length cho) (length jung) (length jong)))
           (remaining (if done (nthcdr size current) nil)))
      (list cho jung jong done remaining))))

;;; ============================================================
;;; 오토마타 상태
;;; ============================================================

(defvar-local my/hangul--current nil)
(defvar-local my/hangul--preedit 0)
(defvar-local my/hangul--overlay nil)

;;; ============================================================
;;; Preedit
;;; ============================================================

(defun my/hangul--char-count (str)
  "STR 의 문자 수 (바이트 수 아님)."
  (length (string-to-list str)))

(defun my/hangul--show (str)
  (when (> my/hangul--preedit 0)
    (delete-char (- my/hangul--preedit)))
  (let ((nchars (my/hangul--char-count str)))
    (if (> nchars 0)
        (progn
          (insert str)
          (setq my/hangul--preedit nchars)
          (unless (and my/hangul--overlay (overlay-buffer my/hangul--overlay))
            (setq my/hangul--overlay (make-overlay (point) (point)))
            (overlay-put my/hangul--overlay 'face '(:underline (:color "yellow" :style line))))
          (move-overlay my/hangul--overlay (- (point) nchars) (point))
          ;; hangul-to-hanja-conversion 이 quail-overlay 위치로 preedit 감지
          (when (overlayp quail-overlay)
            (move-overlay quail-overlay (- (point) nchars) (point))))
      (setq my/hangul--preedit 0)
      (when (and my/hangul--overlay (overlay-buffer my/hangul--overlay))
        (delete-overlay my/hangul--overlay) (setq my/hangul--overlay nil))
      (when (overlayp quail-overlay)
        (move-overlay quail-overlay (point) (point)))))
  (redisplay))

(defun my/hangul--clear ()
  (when (> my/hangul--preedit 0)
    (delete-char (- my/hangul--preedit))
    (setq my/hangul--preedit 0))
  (when (and my/hangul--overlay (overlay-buffer my/hangul--overlay))
    (delete-overlay my/hangul--overlay)
    (setq my/hangul--overlay nil))
  (when (overlayp quail-overlay)
    (move-overlay quail-overlay (point) (point))))

;;; ============================================================
;;; 한자/기호 변환
;;; ============================================================

(defun my/hangul-event-p (event)
  "한글 유니코드 이벤트 여부 확인 (음절/자모/호환자모)."
  (and (integerp event)
       (or (and (>= event #xAC00) (<= event #xD7A3))   ; 한글 음절
           (and (>= event #x1100) (<= event #x11FF))   ; 한글 자모
           (and (>= event #x3130) (<= event #x318F))))) ; 호환 자모

(defun my/hangul-to-hanja-conversion ()
  "직전 한글 문자를 한자/기호로 변환."
  (interactive)
  (let ((hanja (hangul-to-hanja-char (preceding-char))))
    (when hanja
      (delete-char -1)
      (insert (string hanja)))))

(defun my/hangul-to-hanja-at-point ()
  "커서 직전 한글 글자를 한자로 변환 (M-F9)."
  (interactive)
  (let* ((end (point))
         (start (1- end))
         (char-str (if (>= start (point-min))
                       (buffer-substring-no-properties start end)
                     "")))
    (if (not (string-match-p "^[가-힣]$" char-str))
        (message "커서 직전 문자가 한글이 아닙니다.")
      (let* ((char (string-to-char char-str))
             (hanja (hangul-to-hanja-char char)))
        (if (not hanja)
            (message "'%s'에 해당하는 한자가 없습니다." char-str)
          (delete-char -1)
          (insert (string hanja)))))))

;;; ============================================================
;;; Process / Flush / Backspace
;;; ============================================================

(defun my/hangul--process (ch)
  (setq my/hangul--current (append my/hangul--current (list ch)))
  (let* ((result    (my/hangul--run my/hangul--current))
         (cho       (nth 0 result))
         (jung      (nth 1 result))
         (jong      (nth 2 result))
         (done      (nth 3 result))
         (remaining (nth 4 result)))
    (while done
      (my/hangul--clear)
      (let ((str (my/hangul--norm cho jung jong)))
        (when (> (length str) 0) (insert str)))
      (setq my/hangul--current remaining)
      (let* ((r2 (my/hangul--run my/hangul--current)))
        (setq cho       (nth 0 r2)
              jung      (nth 1 r2)
              jong      (nth 2 r2)
              done      (nth 3 r2)
              remaining (nth 4 r2))))
    (my/hangul--show (my/hangul--norm cho jung jong))))

(defun my/hangul--flush ()
  (when my/hangul--current
    (let* ((result (my/hangul--run my/hangul--current))
           (str    (my/hangul--norm (nth 0 result) (nth 1 result) (nth 2 result))))
      (my/hangul--clear)
      (when (> (length str) 0) (insert str))
      (setq my/hangul--current nil))))

(defun my/hangul--backspace ()
  (if (null my/hangul--current)
      (delete-char -1)
    (setq my/hangul--current (butlast my/hangul--current))
    (let* ((result (my/hangul--run my/hangul--current))
           (str    (my/hangul--norm (nth 0 result) (nth 1 result) (nth 2 result))))
      (my/hangul--show str))))

;;; ============================================================
;;; 입력 메서드
;;; ============================================================

(defun my/hangul--alpha-p (key)
  (and (>= key ?A) (<= key ?z) (not (and (> key ?Z) (< key ?a)))))

(defun my/hangul-input-method (key)
  (if (or buffer-read-only
          overriding-terminal-local-map
          (not (my/hangul--alpha-p key)))
      (list key)
    (let ((input-method-function nil) (echo-keystrokes 0) (help-char nil))
      (my/hangul--process (string key))
      (unwind-protect
          (catch 'my/hangul-exit
            (while t
              (let* ((event (read-event nil)))
                (cond
                 ;; C-g → 입력 취소 후 탈출
                 ((eq event ?\C-g)
                  (my/hangul--flush)
                  (my/hangul--clear)
                  (signal 'quit nil))
                 ;; 백스페이스
                 ((eq event 127) (my/hangul--backspace))
                 ;; f9 / Hangul_Hanja → 한자 변환
                 ((or (eq event 'f9) (eq event 'Hangul_Hanja))
                  (my/hangul--flush)
                  (my/hangul-to-hanja-conversion))
                 ;; 알파벳 → 계속 조합
                 ((and (integerp event) (my/hangul--alpha-p event))
                  (my/hangul--process (string event)))
                 ;; 그 외 (Space, Enter, 보조키 등) → 확정 후 Emacs에 전달
                 (t
                  (my/hangul--flush)
                  (setq unread-command-events
                        (cons event unread-command-events))
                  (throw 'my/hangul-exit nil))))))
        (my/hangul--flush)
        (my/hangul--clear)))))

;;; ============================================================
;;; Prefix 키 override (C-x, C-c 등 입력 시 한글 입력기 비활성화)
;;; ============================================================

(defun my/hangul--prefix-override-handler (arg)
  "Prefix 키(C-x, M-x 등) 입력 시 한글 비활성화 후 키를 Emacs에 전달."
  (interactive "P")
  (my/hangul--flush)
  (my/hangul--clear)
  (deactivate-input-method)
  (setq prefix-arg arg)
  (prefix-command-preserve-state)
  (setq unread-command-events
        (append (mapcar (lambda (e) (cons t e))
                        (listify-key-sequence (this-command-keys)))
                unread-command-events)))

(defvar my/hangul--prefix-override-map-enable nil
  "prefix override keymap 활성 여부.")

(defvar my/hangul--prefix-override-map-alist
  `((my/hangul--prefix-override-map-enable
     .
     ,(let ((map (make-sparse-keymap)))
        (dolist (prefix '("C-x" "C-c" "C-h" "M-x"))
          (define-key map (kbd prefix)
                      #'my/hangul--prefix-override-handler))
        map)))
  "prefix override keymap alist.")

(add-to-ordered-list 'emulation-mode-map-alists
                     'my/hangul--prefix-override-map-alist -1000)

;;; ============================================================
;;; 입력기 등록
;;; ============================================================

(defun my/hangul-activate (&rest _)
  (setq deactivate-current-input-method-function #'my/hangul-deactivate)
  (quail-setup-overlays nil)
  (when (eq (selected-window) (minibuffer-window))
    (add-hook 'minibuffer-exit-hook #'quail-exit-from-minibuffer))
  (setq-local input-method-function #'my/hangul-input-method)
  (global-set-key (kbd "<M-f9>") #'my/hangul-to-hanja-at-point)
  (setq my/hangul--prefix-override-map-enable t))

(defun my/hangul-deactivate ()
  (my/hangul--flush) (my/hangul--clear)
  (quail-delete-overlays)
  (kill-local-variable 'input-method-function)
  (setq my/hangul--prefix-override-map-enable nil))

(register-input-method
 "korean-my-hangul" "Korean" #'my/hangul-activate "한2"
 "두벌식 한글 입력기")

(provide 'my-hangul)
;;; my-hangul.el ends here
