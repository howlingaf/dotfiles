;;; theme.el --- paper light / streamer dark -*- lexical-binding: t; -*-
;; Matches the old Doom look:
;;   normal    nano-light dimmed to warm off-white paper (#E9E5DC / #4A4A45)
;;   streamer  doom-one dark  (SPC s s toggles, + hides/unsearches substack)
;; The paper faces are scoped to nano-light, so switching to dark drops them.

(use-package nano-theme :ensure t)
(use-package doom-themes :ensure t)

(defvar vault-streamer-dark-theme 'doom-one "Dark theme while streaming.")

;; The paper overrides as their OWN theme, layered on top of nano-light —
;; enabled last, so its `default' wins (overriding it inside nano-light lost
;; to nano's own default). Dropped cleanly when we switch to dark.
(deftheme vault-paper "Warm off-white paper on top of nano-light.")
(custom-theme-set-faces 'vault-paper
  '(default ((t (:background "#E9E5DC" :foreground "#4A4A45"))))
  '(hl-line ((t (:background "#E1DDD2")))))   ; line a shade darker than paper
(provide-theme 'vault-paper)

(defun vault--paper ()
  "nano-light + the warm off-white paper overlay."
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme 'nano-light t)
  (enable-theme 'vault-paper))

(defun vault--dark ()
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme vault-streamer-dark-theme t))

;; default view = paper
(vault--paper)
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
