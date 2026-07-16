;;; lint.el --- prose spelling+grammar lint (Harper) -*- lexical-binding: t; -*-
;; Harper (harper-ls) via eglot + flymake, ported from the Doom lint.el.
;; OPT-IN per note — never on by default.
;;
;;   SPC l  /  :lint   toggle Harper squiggles in THIS note
;;   K                 (markdown, normal) suggestion popup for the squiggle at point
;;   SPC r             show the diagnostic at the cursor / on this line
;;   SPC s d           toggle the diagnostics list window
;;
;; Vault notes are REMOTE (TRAMP): eglot launches the server where the file
;; lives, so vault buffers use the server's harper-ls (/usr/local/bin), and
;; local buffers use the Windows binary.

(defvar my/harper-ls-path (or (executable-find "harper-ls")
                              "C:/Users/e1319/.local/bin/harper-ls.exe")
  "Local harper-ls for non-vault buffers — found on PATH, else the Windows path.")

;; Recolor Harper's single-severity lints: spelling/typo -> error (red),
;; everything else -> warning (amber).
(defun my/harper-split-severities (_server method &rest args)
  (when (and (eq method 'textDocument/publishDiagnostics)
             (string-suffix-p ".md" (downcase (or (plist-get args :uri) ""))))
    (let ((diags (plist-get args :diagnostics)))
      (when (vectorp diags)
        (seq-doseq (d diags)
          (let ((msg (downcase (or (plist-get d :message) ""))))
            (plist-put d :severity
                       (if (string-match-p "spell\\|typo" msg) 1 2))))))))

(with-eval-after-load 'eglot
  ;; Remote vault notes -> server's harper-ls (remote PATH); local -> Windows.
  (add-to-list 'eglot-server-programs
               `((markdown-mode gfm-mode)
                 . ,(lambda (&rest _)
                      (if (file-remote-p default-directory)
                          '("harper-ls" "--stdio")
                        (list my/harper-ls-path "--stdio")))))
  (advice-add 'eglot-handle-notification :before #'my/harper-split-severities))

;; Lint is OPT-IN PER NOTE (SPC l) — never on by default. eglot auto-manages
;; other markdown buffers once a server is up; this turns flymake back off for
;; any note you didn't explicitly opt in.
(remove-hook 'text-mode-hook #'flymake-mode)

(defvar-local my/prose-lint-enabled nil
  "Non-nil when the user opted this note into prose lint (SPC l).")

(add-hook 'eglot-managed-mode-hook
          (defun my/prose-lint-opt-in ()
            (when (and (derived-mode-p 'markdown-mode)
                       (not my/prose-lint-enabled))
              (flymake-mode -1))))

(defun my/toggle-prose-lint ()
  "Toggle Harper spelling+grammar squiggles in this buffer (SPC l / :lint).
Per-buffer: hides/shows flymake here; the server keeps running for other
notes. Connects on first use — and errors loudly if that fails."
  (interactive)
  (require 'eglot)
  (cond
   ((and (bound-and-true-p eglot--managed-mode) flymake-mode)
    (setq my/prose-lint-enabled nil)
    (flymake-mode -1)
    (message "Prose lint off"))
   ((bound-and-true-p eglot--managed-mode)
    (setq my/prose-lint-enabled t)
    (flymake-mode 1)
    (flymake-start)
    (message "Prose lint on"))
   (t
    (setq my/prose-lint-enabled t)
    (apply #'eglot--connect (eglot--guess-contact))
    (message "Prose lint on — first pass over a long draft takes a few seconds"))))

(defun my/lint--diags-here ()
  "Flymake diagnostics at point, else anywhere on the current line."
  (or (flymake-diagnostics (point))
      (flymake-diagnostics (line-beginning-position) (line-end-position))))

(defun my/diagnostic-at-point ()
  "Show lint diagnostics at the cursor, falling back to the whole line (SPC r)."
  (interactive)
  (let ((diags (my/lint--diags-here)))
    (if diags
        (message "%s" (mapconcat #'flymake-diagnostic-text diags "\n"))
      (message "No lint issues here."))))

(defun my/lint-fixes ()
  "Suggestion popup for the squiggle at point (K in markdown normal mode).
Harper's quickfixes arrive as LSP code actions. Crucial detail (verified
against harper-ls 2.6.0): harper only returns actions when the request range
sits on a SINGLE lint — a whole-line/buffer range comes back empty. So send the
flagged span's exact range, taken from the flymake diagnostic at point (or, if
the cursor is just off it, the first one on the line)."
  (interactive)
  (require 'eglot)
  (let ((diag (car (my/lint--diags-here))))
    (if diag
        ;; 4th arg INTERACTIVE=t — without it eglot-code-actions collects the
        ;; actions silently and never pops the selection menu (that was the
        ;; "nothing happens" bug).
        (eglot-code-actions (flymake-diagnostic-beg diag)
                            (flymake-diagnostic-end diag)
                            nil t)
      (message "No lint issue near point — move onto the underlined text."))))

(defun my/diagnostics-window ()
  (get-window-with-predicate
   (lambda (w) (string-prefix-p "*Flymake diagnostics"
                                (buffer-name (window-buffer w))))))

(defun my/toggle-diagnostics ()
  "Toggle the diagnostics list window and focus it on open (SPC s d)."
  (interactive)
  (let ((win (my/diagnostics-window)))
    (if win
        (quit-window nil win)
      (flymake-show-buffer-diagnostics)
      (when-let ((new (my/diagnostics-window)))
        (select-window new)))))

;; keys — :lint ex command + K for fixes (leader keys live in init.el).
(with-eval-after-load 'evil
  (evil-ex-define-cmd "lint" #'my/toggle-prose-lint))

;; K -> lint fixes. evil-collection binds K (its `lookup-doc' role) to
;; eldoc-doc-buffer in eglot-mode-map — a MINOR-mode keymap that shadows any
;; markdown-mode-map binding, so K just showed the hover text. Override in the
;; BUFFER-LOCAL evil state map (outranks minor-mode maps) once eglot manages the
;; note. Falls through to plain evil-lookup in notes where lint is off.
(defun my/lint-bind-K ()
  (when (and (derived-mode-p 'markdown-mode) (fboundp 'evil-local-set-key))
    (evil-local-set-key 'normal (kbd "K") #'my/lint-fixes)))
(add-hook 'eglot-managed-mode-hook #'my/lint-bind-K)
;; Apply to notes eglot is ALREADY managing (so a live reload takes effect
;; without reopening). Skipped at cold start, where eglot isn't loaded yet.
(when (featurep 'eglot)
  (dolist (b (buffer-list))
    (with-current-buffer b
      (when (bound-and-true-p eglot--managed-mode) (my/lint-bind-K)))))

(provide 'lint)
;;; lint.el ends here
