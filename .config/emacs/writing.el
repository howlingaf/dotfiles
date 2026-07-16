;;; writing.el --- prose-focused writing setup -*- lexical-binding: t; -*-
;; The vault is for writing. Word wrap, centered margins, quiet modeline,
;; font presets, typewriter centering, and a readable-markdown toggle.
;; Ported from ~/.config/doom/writing.el with the Doom macros removed —
;; plain Emacs Lisp you can read top to bottom.
;; Leader keys (bound in init.el): SPC p = pretty markdown, SPC t m = modeline.

;;; --- text flow ---------------------------------------------------------------
;; Wrap at word boundaries everywhere; a paragraph displays as lines.
(global-visual-line-mode 1)
;; One space ends a sentence (kills the typewriter double-space) — makes
;; vim's ( / ) sentence motions work on normal prose.
(setq sentence-end-double-space nil)

;;; --- markdown (the vault is .md) ---------------------------------------------
;; Vanilla Emacs has no bundled markdown-mode — install it and make it the
;; mode for notes. RAW markup by default (you're writing it); SPC p toggles
;; the rendered reading view. Headings scale by level; fenced code blocks get
;; real syntax highlighting.
(use-package markdown-mode
  :mode ("\\.md\\'" . markdown-mode)
  :init
  (setq markdown-header-scaling t
        markdown-header-scaling-values '(1.5 1.3 1.15 1.05 1.0 1.0)
        markdown-fontify-code-blocks-natively t)
  :config
  (markdown-update-header-faces t markdown-header-scaling-values))

;;; --- margins (olivetti) ------------------------------------------------------
;; Centered column so full-screen prose doesn't have eye-losing line sweeps.
;; C-c { / C-c } adjust the width interactively.
(use-package olivetti
  :hook (markdown-mode . olivetti-mode)
  :init (setq-default olivetti-body-width 72))

;;; --- top margin / path bar (header-line) -------------------------------------
;; The header-line FACE (paper-colored, dimmed, tall) lives in theme.el so it
;; tracks the theme. Here we just fill it with the file's path — vault-relative
;; for vault notes, abbreviated otherwise.
(defun my/header-line-path ()
  "The buffer's path — relative to the vault for vault files."
  (let ((f buffer-file-name))
    (cond
     ((and f (boundp 'vault-remote-root) vault-remote-root
           (string-prefix-p vault-remote-root f))
      (substring f (length vault-remote-root)))
     (f (abbreviate-file-name f))
     (t (buffer-name)))))

(defun my/header-line-enable ()
  (setq-local header-line-format '(" " (:eval (my/header-line-path)))))
(add-hook 'find-file-hook #'my/header-line-enable)

;;; --- fonts (fontaine presets) ------------------------------------------------
;; M-x fontaine-set-preset:  regular = Iosevka (mono),
;; writing = Lexend (proportional prose), writing-big = external monitor.
;; The `t' fallback height is `my/font-height' (set in init.el), so presets swap
;; FAMILY without resizing your text.
(use-package fontaine
  :config
  (setq fontaine-presets
        `((regular     :default-family "Iosevka")
          (writing     :default-family "Lexend")
          (writing-big :default-family "Lexend" :default-height 285)
          (t           :default-height ,my/font-height
                       :fixed-pitch-family "Iosevka")))
  (fontaine-set-preset 'regular))

;;; --- typewriter scrolling ----------------------------------------------------
;; Keep the cursor line vertically centered WHILE scrolling (scroll-margin at
;; half the window). No virtual margin — at the top of a file line 1 just sits
;; at the top, so there's nothing to accidentally move the cursor into.

;; C-d/C-u overshoot badly under scroll-margin 9999 (evil scrolls the page AND
;; the margin re-centers, ~doubling the jump). Move the cursor half a window
;; line-wise instead; the centering then scrolls the view to follow.
(defun my/typewriter-half-down ()
  (interactive) (evil-next-visual-line (max 1 (/ (window-body-height) 2))))
(defun my/typewriter-half-up ()
  (interactive) (evil-previous-visual-line (max 1 (/ (window-body-height) 2))))

(define-minor-mode my/typewriter-mode
  "Keep the cursor line vertically centered while scrolling (scroll-margin)."
  :init-value nil
  (if my/typewriter-mode
      (progn
        (setq-local scroll-margin 9999
                    maximum-scroll-margin 0.5)
        (when (fboundp 'evil-local-set-key)
          (dolist (s '(normal visual))
            (evil-local-set-key s (kbd "C-d") #'my/typewriter-half-down)
            (evil-local-set-key s (kbd "C-u") #'my/typewriter-half-up))))
    (kill-local-variable 'scroll-margin)
    (kill-local-variable 'maximum-scroll-margin)
    (when (fboundp 'evil-local-set-key)
      (dolist (s '(normal visual))
        (evil-local-set-key s (kbd "C-d") #'evil-scroll-down)
        (evil-local-set-key s (kbd "C-u") #'evil-scroll-up)))))

(add-hook 'markdown-mode-hook #'my/typewriter-mode)

;; On (re)load: migrate open buffers off the old top-margin implementation
;; (delete any leftover padding overlay + its now-defunct repad hooks, which
;; would otherwise error every keystroke) and re-apply the mode so binding
;; changes take effect without reopening.
(dolist (b (buffer-list))
  (with-current-buffer b
    (when (and (boundp 'my/typewriter--pad) (overlayp my/typewriter--pad))
      (delete-overlay my/typewriter--pad))
    (remove-hook 'post-command-hook 'my/typewriter--repad t)
    (remove-hook 'window-configuration-change-hook 'my/typewriter--repad t)
    (when (bound-and-true-p my/typewriter-mode)
      (my/typewriter-mode -1) (my/typewriter-mode 1))))

;; No line numbers ANYWHERE — also keeps the typewriter padding
;; indistinguishable from blank paper.
(setq display-line-numbers-type nil)

;;; --- modeline: hidden while writing ------------------------------------------
(defun my/mode-line-hide ()
  "Hide the modeline in this buffer."
  (interactive)
  (setq-local mode-line-format nil)
  (force-mode-line-update))

(defun my/mode-line-show ()
  "Bring the modeline back in this buffer."
  (interactive)
  (kill-local-variable 'mode-line-format)
  (force-mode-line-update))

(defun my/mode-line-toggle ()
  "Toggle the modeline in this buffer."
  (interactive)
  (if mode-line-format (my/mode-line-hide) (my/mode-line-show)))

(add-hook 'markdown-mode-hook #'my/mode-line-hide)

(provide 'writing)
;;; writing.el ends here
