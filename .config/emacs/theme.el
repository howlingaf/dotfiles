;;; theme.el --- paper light / streamer dark -*- lexical-binding: t; -*-
;; Matches the old Doom look:
;;   normal    nano-light dimmed to warm off-white paper (#E9E5DC / #4A4A45)
;;   streamer  modus-vivendi — true black (#000000), built into Emacs
;;             (SPC s s toggles, + hides/unsearches substack)
;; The paper faces are scoped to nano-light, so switching to dark drops them.

(use-package nano-theme :ensure t)

(defvar vault-streamer-dark-theme 'modus-vivendi
  "Dark theme while streaming (modus-vivendi = built-in, pure-black bg).")

;; Paper overrides as their OWN theme layered on nano-light — enabled last so
;; its `default' wins (setting it inside nano-light lost to nano's own default).
(deftheme vault-paper "Warm off-white paper on top of nano-light.")
(custom-theme-set-faces 'vault-paper
  '(default ((t (:background "#E9E5DC" :foreground "#4A4A45"))))
  '(hl-line ((t (:background "#E1DDD2"))))    ; line a shade darker than paper
  ;; Top margin + path bar: a header line painted like the paper pushes text
  ;; down from the viewport top and shows the file's (dimmed) path. :height
  ;; scales the gap. writing.el fills header-line-format with the path.
  '(header-line ((t (:background "#E9E5DC" :foreground "#A9A499" :height 1.3
                     :underline nil :overline nil :box nil :inherit nil))))
  ;; Harper (lint.el) squiggles: strong wave underline + soft bg tint so
  ;; they read on paper. Spelling/typo = red, grammar/style = amber.
  '(flymake-error   ((t (:underline (:style wave :color "#C13A2E") :background "#F0D4CD"))))
  '(flymake-warning ((t (:underline (:style wave :color "#A67C00") :background "#ECE1BB")))))
(provide-theme 'vault-paper)

(defun vault--paper ()
  "nano-light + the warm off-white paper overlay."
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme 'nano-light t)
  (enable-theme 'vault-paper))

(defun vault--dark ()
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme vault-streamer-dark-theme t))

;; Apply the theme for the CURRENT mode — paper by default, but dark if we were
;; already streaming, so a live reload (SPC R) doesn't drop us back to light.
(if (bound-and-true-p vault-streamer-mode) (vault--dark) (vault--paper))
(global-hl-line-mode 1)

(defun vault-toggle-streamer-mode ()
  "Streamer mode (SPC s s): dark theme + substack hidden + unsearchable."
  (interactive)
  (setq vault-streamer-mode (not vault-streamer-mode))
  (if vault-streamer-mode (vault--dark) (vault--paper))
  (vault--refresh-dired-omit)
  (message (if vault-streamer-mode
               "🔴 STREAMING — dark; substack hidden + unsearchable"
             "Streaming off — paper; whole vault visible")))
