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
(setq ring-bell-function 'ignore)
(column-number-mode 1)

;;; ---- your remote vault ------------------------------------------------------
;; Reuse the SAME machine-local values as Doom (vault-url, vault-remote-root),
;; then the ported vault.el for search + TRAMP browsing.
;; local.el holds machine-specific values (vault-url, vault-remote-root) and
;; is untracked — self-contained here, no longer borrowed from Doom.
(load (expand-file-name "local.el" user-emacs-directory) t)
(load (expand-file-name "vault.el" user-emacs-directory))
(load (expand-file-name "theme.el" user-emacs-directory))   ; paper / streamer dark
(global-set-key (kbd "C-c f") #'vault-search)   ; find in the vault (also SPC s f)
(global-set-key (kbd "C-c v") #'vault-dired)    ; browse the vault  (also SPC v)

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
    "ss"  '(vault-toggle-streamer-mode :which-key "streamer mode")
    "v"   '(vault-dired          :which-key "vault browse")
    ;; help + quit
    "h"   '(help-command         :which-key "help")
    "q"   '(:ignore t :which-key "quit")
    "qq"  '(save-buffers-kill-terminal :which-key "quit emacs")))
