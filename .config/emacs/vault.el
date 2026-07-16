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
(require 'cl-lib)
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

(defun vault--goto-file-line (file &optional line)
  "Open FILE (absolute or TRAMP path) and jump to LINE (1-based)."
  (find-file file)
  (when line (goto-char (point-min)) (forward-line (1- line))))

(defun vault-open-note (path &optional line)
  "Visit vault note PATH (server-relative), optionally at LINE."
  (vault--goto-file-line (concat vault-remote-root path) line))

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

(defun vault-refresh-corpus ()
  "Drop the cached search index so the next `vault-search' re-fetches.
The server corpus is live, so this makes deletes/edits show up immediately."
  (interactive)
  (setq vault--corpus-lines nil vault--corpus-time nil))

;; A vault note deleted via dired stays in the CACHED search index until the
;; 120s TTL lapses. Invalidate the cache on delete so the next search re-fetches
;; (the server already reflects the deletion).
(defun vault--invalidate-corpus-on-delete (file &rest _)
  (when (and vault-remote-root (string-prefix-p vault-remote-root file))
    (setq vault--corpus-lines nil vault--corpus-time nil)))
(advice-add 'dired-delete-file :after #'vault--invalidate-corpus-on-delete)

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

;;; local org-roam notes — full-text, merged into the same search --------------
;; The remote corpus is markdown only; the org-roam notes (~/howlingaf-notes)
;; are local .org files. Index them the same way so ONE `vault-search' finds
;; both. Read on each search (note sets are small); the remote side stays cached.
(defun vault--org-dir ()
  (expand-file-name
   (if (boundp 'my/org-roam-dir) my/org-roam-dir "~/howlingaf-notes/")))

(defun vault--org-title (line)
  "Return the `#+title:' value from LINE, or nil."
  (when (string-match "^#\\+[Tt][Ii][Tt][Ll][Ee]:[ \t]*\\(.*\\)$" line)
    (string-trim (match-string 1 line))))

(defun vault--org-noise-p (line)
  "Non-nil for org metadata lines (drawers, properties, #+keywords) — not body."
  (string-match-p "^\\(:[A-Za-z]\\|#\\+\\)" line))

(defun vault--local-org-entries ()
  "Full-text entries for local org notes: list of (FILE LINE TEXT REL TITLE)."
  (let ((dir (vault--org-dir)) entries)
    (when (file-directory-p dir)
      (dolist (file (directory-files-recursively dir "\\.org\\'"))
        (with-temp-buffer
          (insert-file-contents file)
          (let ((rel (file-relative-name file dir)) (n 0) title lines)
            (dolist (line (split-string (buffer-string) "\n"))
              (setq n (1+ n))
              (let ((tx (string-trim line)))
                (unless title (setq title (vault--org-title tx)))
                (unless (or (string-empty-p tx) (vault--org-noise-p tx))
                  (push (list file n tx rel) lines))))
            (setq title (or title (file-name-base file)))
            (dolist (e (nreverse lines))
              (push (append e (list title)) entries))))))
    (nreverse entries)))

;;; the search ------------------------------------------------------------------
(defun vault-search ()
  "Fuzzy-search the whole vault AND local org-roam notes; every typed word must
appear in the line.  Note titles match too.  Enter opens the note at that line."
  (interactive)
  (let* ((index (make-hash-table :test 'equal))
         (entries
          (append
           ;; remote markdown vault, from the cached corpus
           (delq nil
                 (mapcar
                  (lambda (l)
                    (when (string-match "^\\(.*?\\):\\([0-9]+\\): \\(.*\\)$" l)
                      (let ((path (match-string 1 l)))
                        (unless (vault--streamer-hidden-p path)
                          (list (concat vault-remote-root path)         ; openable FILE
                                (string-to-number (match-string 2 l))   ; LINE
                                (match-string 3 l)                      ; TEXT
                                path                                    ; REL (display)
                                (file-name-base path))))))              ; TITLE
                  (vault--corpus)))
           ;; local org notes; streamer guard uses their vault-synced path — the
           ;; roam dir's basename is the sub-path they rclone into on the server.
           (let ((sync-prefix (concat (file-name-nondirectory
                                       (directory-file-name (vault--org-dir))) "/")))
             (delq nil
                   (mapcar
                    (lambda (e)
                      (unless (vault--streamer-hidden-p (concat sync-prefix (nth 3 e)))
                        e))
                    (vault--local-org-entries))))))
         (cands
          (let ((i 0) (seen (make-hash-table :test 'equal)) out)
            ;; each candidate = DISPLAY + an invisible unique counter (so lines
            ;; with identical text stay distinct), mapped to its open-target.
            (cl-flet ((add (file ln rel disp)
                        (let ((c (concat disp (propertize (format "​%d" (setq i (1+ i)))
                                                          'invisible t))))
                          (puthash c (list file ln rel) index)
                          (push c out))))
              (dolist (e entries (nreverse out))
                (let ((file (nth 0 e)) (line (nth 1 e)) (text (nth 2 e))
                      (rel (nth 3 e)) (title (nth 4 e)))
                  (unless (gethash file seen)   ; one TITLE candidate per note
                    (puthash file t seen)
                    (add file 1 rel title))
                  (add file line rel text))))))
         (annotate (lambda (cand)
                     (when-let ((tgt (gethash cand index)))
                       (propertize (format "   %s:%d" (nth 2 tgt) (nth 1 tgt)) 'face 'shadow))))
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
    (if target (vault--goto-file-line (nth 0 target) (nth 1 target))
      (user-error "Pick a result line"))))

(provide 'vault)
;;; vault.el ends here
