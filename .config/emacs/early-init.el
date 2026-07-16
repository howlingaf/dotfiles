;;; early-init.el --- runs before the initial frame is created -*- lexical-binding: t; -*-
;; Sizing the frame HERE (not init.el) means it's born at the right size — no
;; brief huge frame that then snaps smaller.

;; Freeze the frame's pixel size when the font changes — otherwise a bigger font
;; re-grows the character-grid frame until it spills across monitors.
(setq frame-inhibit-implied-resize t)

;; Open at a fixed compact pixel size (not maximized). ~half of a 2560x1440
;; primary; adjust to taste.
(push '(width  . (text-pixels . 1300)) default-frame-alist)
(push '(height . (text-pixels . 900))  default-frame-alist)
