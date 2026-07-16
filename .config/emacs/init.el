;;; init.el --- vanilla Emacs: learn Emacs proper + your vault -*- lexical-binding: t; -*-
;;
;; Launch with:  vemacs   (~/.local/bin/vemacs.cmd)
;; 100% SEPARATE from Doom (~/.config/doom) — nothing here touches that.
;; Native Emacs keybindings on purpose: this is the sandbox to learn the
;; editor the way it's meant to be driven. Edit freely, break things, grow it.
;;
;; LEARN, without leaving Emacs:
;;   C-h t      the built-in interactive tutorial   (start here)
;;   C-h r      the full manual (Info)
;;   C-h k KEY  what does this key do?
;;   C-h f FN   describe a function     C-h v VAR  describe a variable
;;   M-x        run any command by name (everything is reachable this way)

;;; ---- packages ---------------------------------------------------------------
;; package.el = Emacs's built-in package manager. use-package (bundled since
;; Emacs 29) is the tidy way to install + configure each one. :ensure auto-
;; installs on first launch.
(require 'package)
(setq package-archives '(("gnu"    . "https://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")
                         ("melpa"  . "https://melpa.org/packages/"))
      ;; Prefer GNU ELPA: its vertico/orderless/marginalia carry matching
      ;; deps, so we avoid MELPA's bleeding-edge "needs compat 31" skew.
      package-archive-priorities '(("gnu" . 10) ("nongnu" . 5) ("melpa" . 0)))
;; Skip GPG signature checks — GNU ELPA packages are signed and verifying
;; needs GnuPG wired into Emacs, which hangs/fails on a bare Windows box.
;; Fine for a personal config; flip to t once you've set up gpg if you care.
(setq package-check-signature nil)
(package-initialize)
(unless package-archive-contents (package-refresh-contents))
(setq use-package-always-ensure t)

;;; ---- modern completion ------------------------------------------------------
;; The biggest quality-of-life jump for vanilla Emacs: a live, fuzzy-filtered
;; minibuffer for M-x, C-x C-f (find file), C-x b (switch buffer), etc.
(use-package vertico :init (vertico-mode))                 ; the list UI
(use-package orderless                                     ; space-separated fuzzy
  :init (setq completion-styles '(orderless basic)))
(use-package marginalia :init (marginalia-mode))           ; notes beside candidates
(which-key-mode 1)                                         ; built into Emacs 30:
                                                           ; shows keys after a prefix

;;; ---- sane defaults ----------------------------------------------------------
(setq inhibit-startup-screen t)
(menu-bar-mode -1) (tool-bar-mode -1) (scroll-bar-mode -1)
(setq make-backup-files nil create-lockfiles nil)
(defalias 'yes-or-no-p 'y-or-n-p)          ; y/n, not the full word
(recentf-mode 1)                           ; recent files (M-x recentf-open)
(savehist-mode 1)                          ; remember minibuffer history
(electric-pair-mode 1)                     ; auto-insert the closing bracket/quote
;; Real breathing room: pad between the frame edge and the text on ALL sides
;; (drawn in the bg color, so it reads as margin — no fake buffer lines). This
;; is the built-in mechanism; `spacious-padding' is the fuller package version.
(add-to-list 'default-frame-alist '(internal-border-width . 24))
(set-frame-parameter nil 'internal-border-width 24)   ; apply live on reload too
;; Keep dired current so a new/changed file shows up. Local dired auto-reverts;
;; the remote vault is NOT polled (auto-revert-remote-files stays nil — no SSH
;; spam), so after saving a file we refresh an open dired of its directory.
(setq global-auto-revert-non-file-buffers t)
(global-auto-revert-mode 1)
(defun my/dired-refresh-saved-dir ()
  "Refresh an open dired buffer showing the just-saved file's directory."
  (when buffer-file-name
    (let ((dir (expand-file-name (file-name-directory buffer-file-name))))
      (dolist (buf (buffer-list))
        (with-current-buffer buf
          (when (and (derived-mode-p 'dired-mode)
                     (equal (expand-file-name default-directory) dir))
            (ignore-errors (revert-buffer))))))))
(add-hook 'after-save-hook #'my/dired-refresh-saved-dir)
(setq ring-bell-function 'ignore)
(column-number-mode 1)
;; Don't pop the *Warnings* buffer for noisy async byte/native-compile warnings
;; from third-party packages (e.g. org-roam's org-version self-check). Real
;; errors still surface; this only silences the package-compile nagging.
(setq native-comp-async-report-warnings-errors 'silent
      warning-suppress-types '((comp) (bytecomp)))
;; Force UTF-8 so em-dashes / curly quotes save without a coding-system prompt.
(prefer-coding-system 'utf-8)
(setq-default buffer-file-coding-system 'utf-8-unix)  ; LF endings, matches the server
;; Frame size (fixed pixels, decoupled from font) lives in early-init.el.

;;; ---- your remote vault ------------------------------------------------------
;; local.el (untracked) holds machine-specific values (vault-url,
;; vault-remote-root); vault.el does search + TRAMP browsing.
(load (expand-file-name "local.el" user-emacs-directory) t)
(load (expand-file-name "vault.el" user-emacs-directory))
(load (expand-file-name "theme.el" user-emacs-directory))   ; paper / streamer dark
(global-set-key (kbd "C-c f") #'vault-search)   ; find in the vault (also SPC s f)
(global-set-key (kbd "C-c v") #'vault-dired)    ; browse the vault  (also SPC v)

;;; ---- font size --------------------------------------------------------------
;; Scale the default font 2.25x. `my/base-font-height' is defvar-captured once
;; so reloads don't compound. `my/font-height' is the single source of truth —
;; fontaine's presets (writing.el) read it too, so size doesn't ride on load
;; order. Change the multiplier to resize; window size is fixed (early-init.el).
(defvar my/base-font-height (face-attribute 'default :height)
  "The default face :height at first load, before any scaling.")
(defvar my/font-height (round (* 2.25 my/base-font-height))
  "Scaled default-face height, shared by init.el and fontaine (writing.el).")
(set-face-attribute 'default nil :height my/font-height)

;;; ---- writing setup ----------------------------------------------------------
;; Prose-focused: word wrap, olivetti margins, quiet modeline, fontaine fonts,
;; typewriter centering, path bar, readable-markdown toggle. Loaded AFTER the
;; font size above so fontaine inherits it (presets swap family, not size).
(load (expand-file-name "writing.el" user-emacs-directory))

;;; ---- vim keys (evil) --------------------------------------------------------
;; evil = vim in text buffers; evil-collection = vim in dired/help/etc. too.
;; `evil-want-keybinding nil' MUST be set before evil loads, or the two fight.
(use-package evil
  :init
  (setq evil-want-keybinding nil        ; let evil-collection own the extra modes
        evil-want-C-u-scroll t          ; C-u scrolls (Emacs C-u is on M-u style)
        evil-undo-system 'undo-redo)    ; native Emacs 28+ undo/redo for u / C-r
  :config
  (evil-mode 1))
(use-package evil-collection
  :after evil
  :config
  (evil-collection-init))

;; Reload the whole config live (safe to re-run). Only early-init.el (frame
;; size) needs a real restart.
(defun my/reload-config ()
  "Reload init.el and everything it loads, live."
  (interactive)
  (load user-init-file)
  (message "Config reloaded."))

;; SPC leader (general.el — the same tool Doom builds its leader on). Add
;; bindings under the `leader!' block below; which-key shows the menu.
(use-package general
  :after evil
  :config
  (general-create-definer leader!
    :states '(normal visual motion)
    :keymaps 'override
    :prefix "SPC")
  (leader!
    "SPC" '(execute-extended-command :which-key "M-x")
    "."   '(find-file            :which-key "find file")
    ","   '(switch-to-buffer     :which-key "switch buffer")
    "w"   '(evil-window-map      :which-key "window")     ; SPC w s / v / d / hjkl
    ;; writing
    "p"   '(markdown-toggle-markup-hiding :which-key "pretty markdown")
    "t"   '(:ignore t            :which-key "toggle")
    "tm"  '(my/mode-line-toggle  :which-key "modeline")
    "l"   '(my/toggle-prose-lint :which-key "prose lint (Harper)")
    "r"   '(my/diagnostic-at-point :which-key "diagnostic here")
    ;; org-roam (notes graph)
    "n"   '(:ignore t            :which-key "notes/roam")
    "nf"  '(org-roam-node-find   :which-key "find/create node")
    "ni"  '(org-roam-node-insert :which-key "insert link")
    "nc"  '(org-roam-capture     :which-key "capture")
    "nl"  '(org-roam-buffer-toggle :which-key "backlinks")
    "ng"  '(my/roam-graph-corner :which-key "graph (toggle widget)")
    "nG"  '(my/org-roam-graph    :which-key "graph (full window)")
    "ns"  '(my/org-roam-sync     :which-key "sync now")
    ;; file
    "f"   '(:ignore t :which-key "file")
    "ff"  '(find-file            :which-key "find")
    "fs"  '(save-buffer          :which-key "save")
    "fr"  '(recentf-open         :which-key "recent")
    ;; buffer
    "b"   '(:ignore t :which-key "buffer")
    "bb"  '(switch-to-buffer     :which-key "switch")
    "bd"  '(kill-current-buffer  :which-key "kill")
    ;; vault
    "s"   '(:ignore t :which-key "search/vault")
    "sf"  '(vault-search         :which-key "vault search")
    "sd"  '(my/toggle-diagnostics :which-key "diagnostics list")
    "ss"  '(vault-toggle-streamer-mode :which-key "streamer mode")
    "v"   '(vault-dired          :which-key "vault browse")
    ;; help + quit
    "h"   '(help-command         :which-key "help")
    "R"   '(my/reload-config     :which-key "reload config")
    "q"   '(:ignore t :which-key "quit")
    "qq"  '(save-buffers-kill-terminal :which-key "quit emacs")))

;;; ---- vim editing behavior ---------------------------------------------------
;; Escape keys (C-c / jk), motions, and other editor tweaks — grown here.
(load (expand-file-name "editor.el" user-emacs-directory))

;;; ---- prose lint (Harper) ----------------------------------------------------
;; Spelling + grammar via harper-ls over eglot. Opt-in per note: SPC l / :lint.
(load (expand-file-name "lint.el" user-emacs-directory))

;;; ---- C++ scratch REPL -------------------------------------------------------
;; "-" jumps to a scratch .cpp from anywhere; C-' compiles+runs it (async).
(load (expand-file-name "cpp.el" user-emacs-directory))

;;; ---- org-roam (zettelkasten + graph) ----------------------------------------
;; Local .org notes in ~/org-roam, synced to ash-1 via rclone on startup+save.
(load (expand-file-name "roam.el" user-emacs-directory))
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(doom-themes evil-collection evil-escape fontaine general marginalia
		 markdown-mode nano-theme olivetti orderless org-roam
		 org-roam-ui vertico)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
