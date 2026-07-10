;;; vault.el --- remote note-vault access for vanilla Emacs -*- lexical-binding: t; -*-
;;
;; Ported from the Doom config's vault.el, stripped of Doom macros — plain
;; Emacs Lisp you can read top to bottom. Machine-local values (vault-url,
;; vault-remote-root) are loaded from ~/.config/doom/local.el by init.el, so
;; there's ONE source of truth shared with the Doom setup.
;; Token: ~/.authinfo  ->  machine vault login token password <token>
;;
;; Commands:  M-x vault-search  (find text/notes)   M-x vault-dired  (browse)

(require 'seq)
(require 'auth-source)
(require 'url)

(defvar vault-url nil "Base URL of the vault server (set in local.el).")
(defun vault--url ()
  (or vault-url (user-error "vault-url unset (see ~/.config/doom/local.el)")))

(defvar vault-remote-root nil
  "TRAMP dir of the vault root, e.g. /sshx:root@host:/root/Vaults/ (local.el).")

(defvar vault--token-cache nil)
(defun vault--token ()
  (or vault--token-cache
      (setq vault--token-cache
            ;; unibyte: a multibyte Authorization header makes url.el reject
            ;; POSTs whose body has real UTF-8.
            (encode-coding-string
             (or (auth-source-pick-first-password :host "vault" :user "token")
                 (user-error "No vault token in ~/.authinfo (machine vault login token password …)"))
             'utf-8))))

;;; browse / open over TRAMP ----------------------------------------------------
(setq tramp-default-method "sshx")          ; inline ssh; reliable on Windows
;; Fewer round-trips: no remote lockfiles, no dired df, trust the stat cache
;; 30s, no ControlMaster probe (Windows OpenSSH has none).
(setq remote-file-name-inhibit-locks t
      dired-free-space nil
      remote-file-name-inhibit-cache 30
      tramp-use-ssh-controlmaster-options nil)

(defun vault-open-note (path &optional line)
  "Visit vault note PATH (server-relative), optionally at LINE."
  (find-file (concat vault-remote-root path))
  (when line (goto-char (point-min)) (forward-line (1- line))))

(defun vault-dired ()
  "Open the vault root in dired — browse, rename (R), create, all over ssh."
  (interactive)
  (unless vault-remote-root (user-error "vault-remote-root unset (local.el)"))
  (dired vault-remote-root))

;;; streamer guard (screen-share) -----------------------------------------------
;; While ON: only `vault-streamer-allowlist' paths are searchable, and
;; `vault-streamer-hidden-dirs' are omitted from dired. (Theme swap lives in
;; theme.el; the toggle command there flips `vault-streamer-mode'.)
(defvar vault-streamer-mode nil)
(defvar vault-streamer-allowlist nil
  "Path prefixes that stay visible while streaming (set in local.el).")
(defvar vault-streamer-hidden-dirs '("substack")
  "Directories omitted from dired while streaming.")

(defun vault--streamer-hidden-p (path)
  (and vault-streamer-mode vault-streamer-allowlist
       (not (seq-some (lambda (p) (string-prefix-p p path)) vault-streamer-allowlist))))

(require 'dired-x)
(defun vault--omit-regexp ()
  "Dired omit pattern: dotfiles always, + private dirs while streaming."
  (if vault-streamer-mode
      (format "\\`\\.\\|\\`%s\\'" (regexp-opt vault-streamer-hidden-dirs))
    "\\`\\."))
(setq dired-omit-files (vault--omit-regexp) dired-omit-verbose nil)
(add-hook 'dired-mode-hook #'dired-omit-mode)

(defun vault--refresh-dired-omit ()
  "Re-apply the omit pattern to every open dired buffer."
  (setq dired-omit-files (vault--omit-regexp))
  (dolist (b (buffer-list))
    (with-current-buffer b
      (when (derived-mode-p 'dired-mode)
        (dired-omit-mode 1) (ignore-errors (revert-buffer))))))

;;; corpus (the search index) — one GET /api/corpus -----------------------------
(defvar vault--corpus-lines nil)
(defvar vault--corpus-time nil)
(defvar vault--corpus-ttl 120 "Seconds before the corpus is refetched.")
(defvar vault--corpus-refreshing nil)

(defun vault--corpus-fetch ()
  "Download every note line as \"path:line: text\" in one request."
  (let* ((url-request-method "GET")
         (url-request-extra-headers
          `(("Authorization" . ,(concat "Bearer " (vault--token)))))
         (buf (url-retrieve-synchronously (concat (vault--url) "/api/corpus") t t 20)))
    (unless buf (user-error "Vault server unreachable (%s)" vault-url))
    (unwind-protect
        (with-current-buffer buf
          (let ((status (bound-and-true-p url-http-response-status))
                (eoh (bound-and-true-p url-http-end-of-headers)))
            (unless (and status (<= 200 status 299))
              (user-error "Vault corpus error %s" status))
            (goto-char (1+ eoh))
            (setq vault--corpus-lines
                  (split-string
                   (decode-coding-string
                    (buffer-substring-no-properties (point) (point-max)) 'utf-8)
                   "\n" t)))
          (setq vault--corpus-refreshing nil
                vault--corpus-time (current-time))
          vault--corpus-lines)
      (kill-buffer buf))))

(defun vault--corpus ()
  "Cached corpus; refreshes on idle when older than `vault--corpus-ttl'."
  (let ((stale (or (null vault--corpus-time)
                   (>= (float-time (time-subtract (current-time) vault--corpus-time))
                       vault--corpus-ttl))))
    (cond
     (vault--corpus-lines
      (when (and stale (not vault--corpus-refreshing))
        (setq vault--corpus-refreshing t)
        (run-with-idle-timer
         0.2 nil (lambda ()
                   (unwind-protect (ignore-errors (vault--corpus-fetch))
                     (setq vault--corpus-refreshing nil)))))
      vault--corpus-lines)
     (t (vault--corpus-fetch)))))

;;; the search ------------------------------------------------------------------
(defun vault-search ()
  "Fuzzy-search the whole vault; every typed word must appear in the line.
Note titles match too.  Enter opens the note at that line."
  (interactive)
  (let* ((index (make-hash-table :test 'equal))
         (cands
          (let ((i 0) (seen (make-hash-table :test 'equal)) out)
            (dolist (l (vault--corpus) (nreverse out))
              (when (string-match "^\\(.*?\\):\\([0-9]+\\): \\(.*\\)$" l)
                (let ((path (match-string 1 l)))
                  (unless (vault--streamer-hidden-p path)   ; streamer allow-list
                    (unless (gethash path seen)   ; one TITLE candidate per note
                      (puthash path t seen)
                      (let ((title (concat (file-name-base path)
                                           (propertize (format "​%d" (setq i (1+ i)))
                                                       'invisible t))))
                        (puthash title (cons path 1) index)
                        (push title out)))
                    (let ((cand (concat (match-string 3 l)
                                        (propertize (format "​%d" (setq i (1+ i)))
                                                    'invisible t))))
                      (puthash cand (cons path (string-to-number (match-string 2 l)))
                               index)
                      (push cand out))))))))
         (annotate (lambda (cand)
                     (when-let ((tgt (gethash cand index)))
                       (propertize (format "   %s:%d" (car tgt) (cdr tgt)) 'face 'shadow))))
         (table (lambda (str pred action)
                  (if (eq action 'metadata)
                      `(metadata (category . vault-match)
                                 (annotation-function . ,annotate))
                    (complete-with-action action cands str pred))))
         ;; literal (ripgrep-style) matching for this prompt
         (completion-styles '(orderless))
         (orderless-matching-styles (list #'orderless-literal))
         (orderless-smart-case nil)
         (completion-ignore-case t)
         (pick (completing-read "Vault search: " table))
         (target (gethash pick index)))
    (if target (vault-open-note (car target) (cdr target))
      (user-error "Pick a result line"))))

(provide 'vault)
;;; vault.el ends here
