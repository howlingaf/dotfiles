;;; editor.el --- vim editing behavior (evil) -*- lexical-binding: t; -*-
;; Motions and editing tweaks, built up piece by piece. Ported from the Doom
;; editor.el with the `map!' macros replaced by plain define-key.

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(with-eval-after-load 'evil
  ;; Escape to normal from every state via C-c (Esc and jk work too; jk is
  ;; evil-escape below). Never triggers the Emacs C-c prefix, so a stray press
  ;; is always safe.
  (define-key evil-insert-state-map   (kbd "C-c") #'evil-normal-state)
  (define-key evil-visual-state-map   (kbd "C-c") #'evil-exit-visual-state)
  (define-key evil-normal-state-map   (kbd "C-c") #'evil-force-normal-state)
  (define-key evil-motion-state-map   (kbd "C-c") #'evil-force-normal-state)
  (define-key evil-operator-state-map (kbd "C-c") #'evil-force-normal-state)

  ;; Move by SCREEN line in wrapped prose — MOTION ONLY. evil-respect-visual-
  ;; line-mode stays nil, so operators keep acting on whole logical lines (dd,
  ;; yy, yap). Mode-specific j/k like dired's still win (global maps only).
  (setq evil-respect-visual-line-mode nil)
  (dolist (map (list evil-normal-state-map evil-visual-state-map))
    (define-key map (kbd "j")      #'evil-next-visual-line)
    (define-key map (kbd "k")      #'evil-previous-visual-line)
    (define-key map (kbd "<down>") #'evil-next-visual-line)
    (define-key map (kbd "<up>")   #'evil-previous-visual-line))

  ;; "_" opens dired on the current file's directory, cursor on the file (like
  ;; vim-vinegar / oil.nvim). In a dired buffer it goes up to the parent.
  ;; Overrides evil's rarely-used "_" motion.
  (define-key evil-normal-state-map (kbd "_") #'dired-jump)

  ;; Seeking text objects: change/delete/yank-inner-paren etc. seek to the next
  ;; pair when point is outside. targets = the evil port of targets.vim, vendored
  ;; to lisp/targets.el (package-vc gives "empty checkout" on Windows); avy lazy.
  (require 'targets)
  (targets-setup t))

;; `jk' leaves insert mode. The 0.15s delay lets a real "jk" in prose through.
(use-package evil-escape
  :after evil
  :init (setq evil-escape-key-sequence "jk"
              evil-escape-delay 0.15)
  :config (evil-escape-mode 1))

(provide 'editor)
;;; editor.el ends here
