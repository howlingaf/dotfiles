;;; init.el --- C / systems profile -*- lexical-binding: t; -*-
;;
;; Launch:  emacs -nw, or attach to the systemd daemon with `ec' / `eg'
;;          (~/.zshrc; unit in ~/.config/systemd/user/emacs-c.service).
;;
;; The point of this profile is the two things Emacs genuinely does better than
;; nvim for this work: `M-x gdb' (live source/locals/registers/stack) and magit.
;; Everything else deliberately mirrors the nvim setup — bottom splits, no
;; floats, centered cursor, no diagnostics, build-on-save.
;;
;; Survival kit, if evil isn't loaded yet or you get stuck:
;;   C-g       cancel anything (this is <Esc>)
;;   M-x       run a command by name
;;   C-x C-c   quit          (`:q' works once evil is up)
;;   <f1> t    the built-in tutorial      <f1> k KEY   what does this key do?

;;; ---- packages ---------------------------------------------------------------
;; Own elpa/ under this directory, so the writing profile's packages are
;; untouched. First launch downloads ~8 packages; needs network.
(require 'package)
(setq package-archives '(("gnu"    . "https://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")
                         ("melpa"  . "https://melpa.org/packages/"))
      package-archive-priorities '(("gnu" . 10) ("nongnu" . 5) ("melpa" . 0)))
(package-initialize)
(unless package-archive-contents (package-refresh-contents))
;; Emacs autoloads only use-package-core, and `:ensure' is implemented in a
;; separate file (use-package-ensure.el). Without this require the keyword is
;; silently DROPPED — the macro still works, :init still runs, and nothing
;; ever installs. Requiring the full package registers the handler.
(require 'use-package)
(setq use-package-always-ensure t)

;;; ---- minibuffer completion --------------------------------------------------
;; Same three as the writing profile: live filtered M-x / find-file / buffers.
(use-package vertico :init (vertico-mode))
(use-package orderless :init (setq completion-styles '(orderless basic)))
(use-package marginalia :init (marginalia-mode))
(which-key-mode 1)                      ; built in since Emacs 30

;;; ---- defaults ---------------------------------------------------------------
(setq inhibit-startup-screen t
      make-backup-files nil
      create-lockfiles nil
      ring-bell-function 'ignore
      native-comp-async-report-warnings-errors 'silent)
(menu-bar-mode -1)
(when (fboundp 'tool-bar-mode)   (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(defalias 'yes-or-no-p 'y-or-n-p)
(recentf-mode 1)                        ; SPC f r  — the <leader>a equivalent
(savehist-mode 1)
(column-number-mode 1)
(global-auto-revert-mode 1)             ; pick up files changed outside Emacs
(prefer-coding-system 'utf-8)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
;; No theme on purpose. The default is already the plain one you wanted.

;; Keep the cursor vertically centered — the center_cursor autocmd, natively.
;; scroll-margin larger than the window forces recentering on every move;
;; maximum-scroll-margin caps it at half a window, i.e. dead center.
(setq scroll-preserve-screen-position t
      scroll-conservatively 0
      maximum-scroll-margin 0.5
      scroll-margin 99999)

;; evil's C-d/C-u read `scroll-margin' RAW — evil-scroll-down does
;; `(next-line (- scroll-margin row))', which with 99999 is a leap toward the
;; end of the buffer, while evil-scroll-up's arithmetic happens to clamp. Emacs
;; itself caps the margin at half a window (maximum-scroll-margin); evil does
;; not. Run both with a zero margin, then recenter, so each moves exactly half
;; a window and the cursor stays centred.
(defun my/evil-scroll-centred (orig &rest args)
  (let ((scroll-margin 0)) (apply orig args))
  (recenter))
(advice-add 'evil-scroll-down :around #'my/evil-scroll-centred)
(advice-add 'evil-scroll-up   :around #'my/evil-scroll-centred)

;; K&R indentation, since that's the book.
(setq c-default-style "k&r"
      c-basic-offset 2)
(setq-default indent-tabs-mode nil)

;;; ---- colours: nvim's default scheme -----------------------------------------
;; There is no colourscheme plugin in ~/.config/nvim — it runs the stock default,
;; with lua/local.lua forcing the editor background to pure black. These are that
;; scheme's actual values, read out of `nvim --clean' with termguicolors on.
;;
;; The background is #010101, not #000000, on purpose. In a 24-bit terminal
;; Emacs encodes a direct colour as its packed RGB value, then treats any value
;; below 256 as a PALETTE index: #000000 packs to 0 and goes out as `ESC[40m'
;; (ANSI black — alacritty draws that from its palette as charcoal, not from
;; its primary background), and #000001..#0000FF would go out as red, green...
;; #010101 packs to 65793, above the palette range, so it is sent as true RGB.
;; On screen (1,1,1) is black.
;; Note how little is coloured: comments, strings, variables, functions, and
;; nothing else. Keywords are bold in the default foreground, not tinted.
(defvar my/nvim-faces
  '((default                          :foreground "#e0e2ea" :background "#010101")
    (fringe                           :background "#010101")
    (font-lock-comment-face           :foreground "#9b9ea4" :weight normal)
    (font-lock-comment-delimiter-face :foreground "#9b9ea4" :weight normal)
    (font-lock-string-face            :foreground "#b3f6c0" :weight normal)
    (font-lock-doc-face               :foreground "#b3f6c0" :weight normal)
    (font-lock-variable-name-face     :foreground "#a6dbff" :weight normal)
    (font-lock-function-name-face     :foreground "#8cf8f7" :weight normal)
    (font-lock-builtin-face           :foreground "#8cf8f7" :weight normal)   ; nvim Special
    (font-lock-keyword-face           :foreground "#e0e2ea" :weight bold)
    (font-lock-constant-face          :foreground "#e0e2ea" :weight normal)
    (font-lock-type-face              :foreground "#e0e2ea" :weight normal)
    (font-lock-preprocessor-face      :foreground "#e0e2ea" :weight normal)
    (line-number                      :foreground "#4f5258" :weight normal)
    (header-line                      :foreground "#9b9ea4" :background "#010101"
                                      :weight normal :box nil :inherit nil)
    (line-number-current-line         :foreground "#e0e2ea" :weight normal)
    (hl-line                          :background "#2c2e33")   ; nvim CursorLine
    (region                           :background "#4f5258" :extend t)   ; nvim Visual
    (show-paren-match                 :background "#4f5258" :weight bold)
    (isearch                          :foreground "#eef1f8" :background "#6b5300")
    (lazy-highlight                   :foreground "#eef1f8" :background "#6b5300")
    (font-lock-warning-face           :foreground "#ffc0b9" :weight normal)
    (error                            :foreground "#ffc0b9" :weight normal))
  "nvim's default highlight groups, mapped onto Emacs font-lock faces.")

(defun my/apply-nvim-faces ()
  "Apply `my/nvim-faces' to all frames, present and future.
Faces whose library has not loaded yet are SKIPPED rather than set:
`set-face-attribute' signals \"Invalid face\" on an unknown face, and a single
error would abort the rest of the list. `hl-line' and `show-paren-match' are the
two that arrive late, so pull their libraries in first."
  (interactive)
  (require 'hl-line nil t)
  (require 'paren nil t)
  (dolist (spec my/nvim-faces)
    (if (facep (car spec))
        (apply #'set-face-attribute (car spec) nil (cdr spec))
      (message "my/apply-nvim-faces: no such face yet: %s" (car spec)))))
;; Applied on `window-setup-hook', not here: Emacs re-evaluates defface specs
;; when it works out the frame's background mode, which happens AFTER init.el
;; and would otherwise reset faces that ship tty-specific defaults (`region'
;; snapping back to blue3 is the visible symptom). Also re-applied for each new
;; frame, so `emacsclient' and GUI frames match.
(my/apply-nvim-faces)
(add-hook 'window-setup-hook #'my/apply-nvim-faces)
(add-hook 'after-make-frame-functions
          (lambda (_frame) (my/apply-nvim-faces)))

;;; ---- clipboard from a terminal frame -------------------------------------------
;; A tty emacs has no X connection, so kills only reach emacs's own kill ring.
;; OSC 52 is the escape sequence that asks the terminal to set the clipboard;
;; alacritty honours it out of the box. Emacs only emits it when it believes
;; the terminal supports it, and its probe does not recognise alacritty, so
;; declare the capability instead of letting it check. (GUI frames never
;; needed this; `select-enable-clipboard' covers them.)
(setq xterm-extra-capabilities '(modifyOtherKeys reportBackground setSelection))

;;; ---- bottom splits, no floats -----------------------------------------------
;; Every transient buffer (build output, man, help, grep, shell) opens in one
;; reused bottom window at 40% — the bottom_split helper from term.lua.
;; NOTE: gdb-many-windows builds its own layout and will fight a side window.
;; Press C-x 1 (or SPC w o) to clear the frame before starting gdb.
(setq display-buffer-alist
      '(("\\*\\(compilation\\|Man \\|Help\\|shell\\|terminal\\|ansi-term\\|claude\\|eldoc\\|Occur\\|xref\\|grep\\|Warnings\\|Async Shell\\)"
         (display-buffer-reuse-window display-buffer-in-side-window)
         (side . bottom)
         (slot . 0)
         ;; `window-height' is applied only when the window is CREATED (and
         ;; after `body-function' ran); `body-function' runs on every display,
         ;; including into the reused window. Both fit, so the dock is always
         ;; sized for the buffer it shows — short for everything but Claude.
         (window-height . my/fit-dock)
         (body-function . my/fit-dock))))

(defvar my/term-height 0.4  "Dock height as a fraction of the frame.")
(defvar my/term-height-tall 0.8 "Dock height when zoomed with `my/toggle-shell-zoom'.")
(defvar my/ai-height 0.75
  "Dock height for the AI session — a TUI needs more rows than a shell prompt.")

(defun my/ai-buffer-p (&optional buf)
  "Non-nil if BUF (default: current) is any project's Claude dock."
  (string-prefix-p "*claude: " (buffer-name (or buf (current-buffer)))))

(defun my/bottom-dock-p (window)
  (eq (window-parameter window 'window-side) 'bottom))

(defun my/dock-set-height (window fraction)
  "Resize dock WINDOW to FRACTION of its frame's height."
  (ignore-errors
    (window-resize window
                   (- (round (* (frame-height (window-frame window)) fraction))
                      (window-height window))
                   nil t)))

(defun my/fit-dock (window)
  "Size the bottom dock WINDOW for its buffer: tall for Claude, short otherwise.
`window-height' and `body-function' for `display-buffer-alist'."
  (when (my/bottom-dock-p window)
    (my/dock-set-height window (if (my/ai-buffer-p (window-buffer window))
                                   my/ai-height
                                 my/term-height))))

;;; ---- the watcher, natively --------------------------------------------------
;; watcher.sh exists because :w in nvim doesn't trigger a build, so it needed
;; inotify to notice. Emacs doesn't: after-save-hook fires in-process, and
;; compilation-mode already parses gcc output — so every `file.c:12:5: error'
;; is a live jump target (RET on it, or M-g n). That is the whole watcher plus
;; the gf/gd-on-output feature you hand-rolled, built in and with no escape
;; sequences to strip.
(setq compile-command "make"
      compilation-scroll-output nil     ; stay at the top, like the watcher header
      compilation-always-kill t         ; never ask "kill running compilation?"
      compilation-ask-about-save nil)

(defun my/project-root ()
  "Nearest directory above the current buffer holding a Makefile, else .git."
  (or (locate-dominating-file (or buffer-file-name default-directory) "Makefile")
      (locate-dominating-file (or buffer-file-name default-directory) ".git")
      default-directory))

(defun my/watcher-prod-line ()
  "The `prod' TARGETS entry of the project's watcher.sh: (MAKE-TARGET . RUN-CMD).
watcher.sh stays the single source of truth for what to build and run, exactly
as it was under nvim; the emacs hook just executes the same line."
  (let ((f (expand-file-name "watcher.sh" (my/project-root))))
    (when (file-readable-p f)
      (with-temp-buffer
        (insert-file-contents f)
        (when (re-search-forward "^[ \t]*\"prod[ \t]*|[ \t]*\\([^|]+?\\)[ \t]*|[ \t]*\\([^|\"]+?\\)[ \t]*[|\"]" nil t)
          (cons (match-string 1) (match-string 2)))))))

(defun my/run-stem ()
  "Textbook projects (one program per .c file): the stem of the exercise the
current buffer belongs to. `1-20.c' and `1-20.in' both give \"1-20\". Not in
such a file: the most recently edited .c in the project, as watcher.sh does."
  (let ((f buffer-file-name))
    (if (and f (member (file-name-extension f) '("c" "in")))
        (file-name-base f)
      (let* ((root (my/project-root))
             (cs (directory-files root t "\\.c\\'"))
             (newest (car (sort cs (lambda (a b)
                                     (time-less-p (file-attribute-modification-time (file-attributes b))
                                                  (file-attribute-modification-time (file-attributes a))))))))
        (and newest (file-name-base newest))))))

(defun my/build-command ()
  "Build, then run — the watcher's prod pass. Plain `make' if no watcher.sh.
A `$RUN' in the run command (textbook mode, see kandr/watcher.sh) becomes the
stem of the exercise being edited, the way watcher.sh sets it from the file
that was just saved."
  (let ((prod (my/watcher-prod-line)))
    (if prod
        (let ((cmd (format "make %s && %s" (car prod) (cdr prod))))
          (if (string-match-p "\\$RUN" cmd)
              (replace-regexp-in-string "\\\\?\\$RUN" (or (my/run-stem) "") cmd t t)
            cmd))
      compile-command)))

(defun my/compile-project ()
  "Run the project's build-and-run pass in the *compilation* buffer."
  (interactive)
  (let ((default-directory (my/project-root)))
    (compile (my/build-command))))

(defvar my/auto-compile t
  "When non-nil, rebuild after saving a C buffer.")

(defun my/toggle-auto-compile ()
  "Turn build-on-save on or off."
  (interactive)
  (setq my/auto-compile (not my/auto-compile))
  (message "build-on-save %s" (if my/auto-compile "ON" "OFF")))

(defun my/maybe-recompile ()
  "Rebuild after saving C source, or an exercise's .in input file."
  (when (and my/auto-compile
             buffer-file-name
             (or (derived-mode-p 'c-mode 'c-ts-mode 'c++-mode 'c++-ts-mode)
                 (and (equal (file-name-extension buffer-file-name) "in")
                      (file-exists-p (concat (file-name-sans-extension buffer-file-name) ".c")))))
    (my/compile-project)))
(add-hook 'after-save-hook #'my/maybe-recompile)

;; ripgrep across the project into a grep-mode buffer (next-error works).
(defun my/rg (regexp)
  "Ripgrep REGEXP under the project root, and put the cursor in the results."
  (interactive "sripgrep: ")
  (let* ((default-directory (my/project-root))
         (buf (compilation-start
               ;; --sort path: rg searches in parallel and otherwise emits
               ;; matches in whatever order threads finish, so the "first"
               ;; result changes run to run. Sorted, results group by file.
               (format "rg --vimgrep --no-heading --sort path %s" (shell-quote-argument regexp))
               'grep-mode)))
    (select-window (get-buffer-window buf))))

(defun my/rg-word-at-point ()
  "Ripgrep the word under the cursor, as a whole word, across the project.
Same results buffer as `my/rg', so RET, Esc and the cursor behave the same."
  (interactive)
  (let ((word (thing-at-point 'symbol t)))
    (unless word (user-error "No word under cursor"))
    (my/rg (format "\\b%s\\b" (regexp-quote word)))))

(defmacro my/in-main-window (&rest body)
  "Run BODY with every `display-buffer' forced into the main window.
Jumping to a result from a dock would otherwise let `display-buffer' split the
frame, because a side window cannot hold a file buffer and the default action
pops a new window rather than reusing the main one."
  `(let* ((main (my/main-window))
          (display-buffer-overriding-action
           (list (lambda (buffer _alist) (set-window-buffer main buffer) main))))
     ,@body))

(defun my/goto-result ()
  "RET in grep/compilation results: open the match in the main window.
Search results then get out of the way, same as gf from a terminal. Build
output stays, per `my/sticky-dock-buffers' — it is a worklist."
  (interactive)
  (let ((origin (buffer-name)))
    (my/in-main-window (compile-goto-error))
    (unless (member origin my/sticky-dock-buffers)
      (my/hide-docks))))

(defun my/next-result ()
  "Next error/match, shown in the main window."
  (interactive)
  (my/in-main-window (next-error)))

(defun my/previous-result ()
  "Previous error/match, shown in the main window."
  (interactive)
  (my/in-main-window (previous-error)))

(defun my/rg--goto-first-match (buf _status)
  "When a search finishes, put the cursor on its first match, not the header."
  (when (and (eq (buffer-local-value 'major-mode buf) 'grep-mode)
             (get-buffer-window buf))
    (with-selected-window (get-buffer-window buf)
      (goto-char (point-min))
      (ignore-errors (compilation-next-error 1)))))
(add-hook 'compilation-finish-functions #'my/rg--goto-first-match)

(defun my/cancel-results ()
  "Esc in search results: kill the search if it is still running, and close."
  (interactive)
  (when (get-buffer-process (current-buffer))
    (kill-compilation))
  (quit-window))

(with-eval-after-load 'evil
  (dolist (hook '(grep-mode-hook compilation-mode-hook))
    (add-hook hook (lambda () (evil-local-set-key 'normal (kbd "RET") #'my/goto-result))))
  ;; Every result line carries a `keymap' TEXT PROPERTY (compilation-button-map),
  ;; and property keymaps outrank evil's maps entirely — so on an actual match,
  ;; RET was reaching the stock `compile-goto-error', which jumps but never
  ;; hides. The binding above only ever applied on the header line.
  (with-eval-after-load 'compile
    (define-key compilation-button-map (kbd "RET") #'my/goto-result))
  (add-hook 'grep-mode-hook
            (lambda () (evil-local-set-key 'normal (kbd "<escape>") #'my/cancel-results))))

;; Esc cancels any minibuffer prompt, the way it leaves insert mode. Bare Esc
;; is otherwise the Meta prefix, so out of the box only C-g (or Esc Esc Esc)
;; aborts. evil's esc-mode already turns a lone terminal ESC into <escape>.
(dolist (map (list minibuffer-local-map minibuffer-local-ns-map
                   minibuffer-local-completion-map minibuffer-local-must-match-map
                   minibuffer-local-isearch-map))
  (define-key map (kbd "<escape>") #'abort-minibuffers))
(with-eval-after-load 'vertico
  (define-key vertico-map (kbd "<escape>") #'abort-minibuffers))

(use-package vterm
  :commands (vterm)
  :init
  ;; Build vterm-module.so on install instead of prompting. libvterm 0.3.3 and
  ;; its headers are already on this system, so this compiles against the same
  ;; emulator nvim uses for :terminal.
  (setq vterm-always-compile-module t)
  :config
  (setq vterm-max-scrollback 10000
        vterm-kill-buffer-on-exit t))

;;; ---- bottom shell ------------------------------------------------------------
;; The Shift-Space terminal, as a toggle. Hiding a side window does NOT kill the
;; process — the buffer keeps running and returns with its scrollback intact.
;;
;; Uses `ansi-term', NOT `shell'. `shell' is comint — a process attached to an
;; ordinary editable buffer, not a terminal: the prompt is plain text you can
;; backspace over, and zsh sees TERM=dumb and switches `zle' OFF. That would kill
;; bindkey -v, the jk binding, the widgets, and _center_prompt's \e[6n query.
;; ansi-term is a real VT emulator, so ~/.zshrc behaves as it does anywhere else.
(defvar my/term-buffer-name "*shell-term*"
  "Bottom terminal buffer. `ansi-term' wraps its NAME argument in asterisks.")

(defun my/toggle-shell ()
  "Show the bottom terminal, or hide it if it is already showing."
  (interactive)
  (let* ((buf (get-buffer my/term-buffer-name))
         (win (and buf (get-buffer-window buf))))
    (cond
     (win (delete-window win))                  ; visible -> hide, process lives
     (buf (pop-to-buffer buf))                  ; alive but hidden -> show
     (t   (let ((default-directory (my/project-root)))
            (my/spawn-terminal))))))

(defun my/spawn-terminal ()
  "Create the bottom terminal.
Prefers vterm — libvterm, the same C emulator nvim drives for :terminal.
Falls back to the built-in `ansi-term' if the compiled module is unavailable,
so a failed or stale build can never leave the profile without a terminal."
  (if (require 'vterm nil t)
      (let ((vterm-buffer-name my/term-buffer-name))
        (vterm))
    ;; `ansi-term' ends in `switch-to-buffer', which ignores
    ;; `display-buffer-alist' and swallows the whole frame; this routes that one
    ;; call through `display-buffer' so it docks like everything else.
    (let ((switch-to-buffer-obey-display-actions t))
      (ansi-term (or explicit-shell-file-name (getenv "SHELL") "/bin/sh")
                 "shell-term"))))

(defun my/toggle-shell-zoom ()
  "Grow the terminal dock, or shrink it back.
The dock is short on purpose, but a REPL like clox needs room. In a terminal
frame this is the ONLY way to get more lines: `emacs -nw' cannot change font
size, because the font belongs to the outer terminal (`display-multi-font-p'
is nil there)."
  (interactive)
  (let ((win (get-buffer-window my/term-buffer-name)))
    (if (not win)
        (message "Terminal is not visible — C-SPC first.")
      (let* ((total (frame-height))
             (cur   (window-height win))
             (tall  (round (* total my/term-height-tall)))
             (norm  (round (* total my/term-height))))
        (my/dock-set-height win (if (> cur (/ (+ tall norm) 2))
                                    my/term-height
                                  my/term-height-tall))
        (message "Terminal dock: %d rows" (window-height win))))))

;; Shrink the text in the terminal buffer so more lines fit in the same dock.
;; No-op on a terminal frame, where there is only one font — guarded rather
;; than skipped so the same config does the right thing if you launch a GUI
;; frame (see the `eg' alias).
(defvar my/term-text-scale -2
  "`text-scale' steps applied to the terminal dock on graphical frames.")

(defun my/shrink-terminal-text ()
  (when (display-multi-font-p)
    (text-scale-set my/term-text-scale)))
(add-hook 'vterm-mode-hook #'my/shrink-terminal-text)
(add-hook 'term-mode-hook  #'my/shrink-terminal-text)

;; If a comint buffer does turn up (M-x shell, M-x gdb), stop backspace from
;; eating the prompt. Comint defaults this to nil because the buffer is meant to
;; be editable text; that is exactly the behavior that reads as broken.
(setq comint-prompt-read-only t)

;; C-SPC toggles it, the way Ctrl-Space did in nvim. This takes over
;; `set-mark-command' — no real loss under evil, where `v' starts a selection.
;; Bound globally (evil states fall through to global for keys they don't bind)
;; and again inside the shell, so the same chord closes it from within.
;;
;; Ctrl-Space is TWO different key events depending on the frame: a GUI frame
;; delivers C-SPC ([67108896]), while a terminal sends NUL, which Emacs reads as
;; C-@ ([0]). Binding only the first does nothing under `emacs -nw'. Bind both.
(defvar my/ctrl-space-keys (list (kbd "C-SPC") (kbd "C-@"))
  "How Ctrl-Space arrives in a GUI frame and in a terminal, respectively.")
(dolist (k my/ctrl-space-keys)
  (global-set-key k #'my/toggle-dock))
(with-eval-after-load 'shell
  (dolist (k my/ctrl-space-keys)
    (define-key shell-mode-map k #'my/toggle-dock)))
;; ansi-term in char mode forwards nearly every key to the process;
;; term-raw-map is the escape hatch for keys Emacs should keep for itself.
(with-eval-after-load 'term
  (dolist (k my/ctrl-space-keys)
    (define-key term-raw-map k #'my/toggle-dock)))
(with-eval-after-load 'vterm
  (dolist (k my/ctrl-space-keys)
    (define-key vterm-mode-map k #'my/toggle-dock)))

;; Inside a terminal, Esc and C-c belong to the PROGRAM, exactly as in nvim's
;; :terminal. evil-collection instead routes Esc to evil-normal-state and C-c to
;; a prefix map, so nothing running in the dock ever sees them: Claude Code's
;; vim mode never leaves insert (dd types "dd"), and zsh's `bindkey -v' cannot
;; work. Hand both to the process, and use nvim's own escape hatch, C-\ C-n, to
;; drop to evil normal state for scrollback. `i' resumes typing.
(defun my/vterm-passthrough-keys ()
  "Buffer-local, on purpose: evil-collection defines C-c C-z in `vterm-mode-map'
itself, and binding C-c to a command IN that map makes its `define-key' fail
(\"starts with non-prefix key C-c\"). Local bindings shadow the map without
touching it, so both coexist."
  (evil-local-set-key 'insert (kbd "<escape>") #'vterm-send-escape)
  (evil-local-set-key 'insert (kbd "C-c")      #'vterm-send-C-c)
  (evil-local-set-key 'insert (kbd "C-\\ C-n") #'evil-normal-state)
  ;; Leaving normal state always returns to the LIVE cursor. evil-collection's
  ;; i/a/A/I instead try to move the terminal cursor to where point is — a
  ;; shell line-editing feature that means nothing up in the scrollback, and
  ;; leaves the view where it was until the next keystroke forces a redraw.
  (dolist (k '("i" "a" "A" "I"))
    (evil-local-set-key 'normal (kbd k) #'my/vterm-resume)))

(defun my/vterm-resume ()
  "Back to the terminal's live cursor, in insert state, with it at the bottom."
  (interactive)
  (vterm-reset-cursor-point)
  (evil-insert-state)
  (recenter -1))
(add-hook 'vterm-mode-hook #'my/vterm-passthrough-keys 90)   ; after evil-collection

;; :ai / :noai as real ex commands, same as on the nvim side.
(with-eval-after-load 'evil
  (evil-ex-define-cmd "ai"   #'my/ai-on)
  (evil-ex-define-cmd "noai" #'my/ai-off))
(with-eval-after-load 'savehist
  (add-to-list 'savehist-additional-variables 'my/ai-enabled))
;; Evil's state maps outrank `global-map', and insert state already binds C-@ to
;; `evil-paste-last-insertion-and-stop-insert' (vim's C-@) — which is why pressing
;; Ctrl-Space while inserting reported "Register is empty" instead of toggling.
;; Claim the chord in every state.
(with-eval-after-load 'evil
  (dolist (map (list evil-normal-state-map evil-insert-state-map
                     evil-visual-state-map evil-motion-state-map
                     evil-replace-state-map evil-emacs-state-map))
    (dolist (k my/ctrl-space-keys)
      (define-key map k #'my/toggle-dock))))

(defun my/toggle-build ()
  "Show the build-output dock, or hide it if it is already showing.
The build itself runs on `after-save-hook'; this only summons the transcript,
where every `file.c:12:5: error' is a jump target (RET, or gf)."
  (interactive)
  (let* ((buf (get-buffer "*compilation*"))
         (win (and buf (get-buffer-window buf))))
    (cond
     (win (delete-window win))
     (buf (pop-to-buffer buf))
     (t   (my/compile-project)))))

;; Shift-Space. A terminal sends plain 0x20 for it — indistinguishable from SPC
;; — so it can only ever reach a GUI frame on its own. alacritty.toml is already
;; configured to send CSI 32;2u instead, so decode that back into the S-SPC
;; event and the key works under `ec' as well as `eg'.
(defvar my/shift-space-sequences
  '("\e[27;2;32~"   ; xterm modifyOtherKeys — what tmux re-encodes it as
    "\e[32;2u")     ; kitty CSI-u — what alacritty sends when there is no tmux
  "Byte sequences a terminal may deliver for Shift-Space.
tmux does not pass the outer terminal's encoding through: it decodes the key and
re-emits it in its own format, so both forms have to be decoded.")

(defun my/decode-shift-space ()
  (dolist (seq my/shift-space-sequences)
    (define-key input-decode-map seq (kbd "S-SPC"))))
(add-hook 'tty-setup-hook #'my/decode-shift-space)
(unless (display-graphic-p) (my/decode-shift-space))

(global-set-key (kbd "S-SPC") #'my/toggle-build)
(with-eval-after-load 'evil
  (dolist (map (list evil-normal-state-map evil-insert-state-map
                     evil-visual-state-map evil-motion-state-map
                     evil-replace-state-map evil-emacs-state-map))
    (define-key map (kbd "S-SPC") #'my/toggle-build)))
(with-eval-after-load 'vterm
  (define-key vterm-mode-map (kbd "S-SPC") #'my/toggle-build))
(with-eval-after-load 'term
  (define-key term-raw-map (kbd "S-SPC") #'my/toggle-build))

(defun my/ai-root ()
  "Repo root the AI dock should belong to.
The current buffer's repo; failing that (scratch, build output, a man page —
none of which live in a repo) the repo of the file in the main window. Without
this, C-SPC from such a buffer fell back to the daemon's cwd, ~, and launched
`claude -c' where there is no conversation to continue."
  (cl-flet ((repo-of (buf)
              (with-current-buffer buf
                (let ((d (locate-dominating-file default-directory ".git")))
                  (and d (expand-file-name d))))))
    (or (repo-of (current-buffer))
        (repo-of (window-buffer (my/main-window)))
        ;; most recently used file buffer — `buffer-list' is MRU-ordered
        (let ((f (seq-find #'buffer-file-name (buffer-list))))
          (and f (repo-of f)))
        ;; nothing open anywhere (fresh daemon): ask, from the known projects
        (expand-file-name (project-prompt-project-dir)))))

(defun my/ai-buffer-name ()
  "Name of the Claude dock for the project the current buffer belongs to.
One session per repo — *claude: kandr*, *claude: craftinginterpreters-clox* —
so switching projects switches sessions, and each keeps running while hidden."
  (format "*claude: %s*"
          (file-name-nondirectory (directory-file-name (my/ai-root)))))

(defun my/claude-has-session-p (root)
  "Non-nil if Claude Code has a stored conversation for ROOT.
Claude keys its store by the directory path with / and . replaced by -."
  (let ((store (expand-file-name
                (concat (replace-regexp-in-string
                         "[/.]" "-" (directory-file-name (expand-file-name root)))
                        "/")
                "~/.claude/projects/")))
    (and (file-directory-p store)
         (directory-files store nil "\\.jsonl\\'"))))

(defvar my/ai-args "-c"
  "Arguments for the `claude' CLI. -c resumes the previous session for this
project rather than starting a fresh one.")

(defun my/ai--shell-command (root)
  "Command line vterm runs for the AI dock rooted at ROOT.
Passes `my/ai-args' (-c, resume) only when ROOT has a conversation to resume;
otherwise starts fresh — `claude -c' with nothing to continue just exits, and
the dock vanished with it. vterm interpolates `vterm-shell' into
`/bin/sh -c \"... exec %s\"', so arguments are honoured."
  (let ((args (if (my/claude-has-session-p root) my/ai-args
                (message "No Claude conversation in %s yet — starting a new one"
                         (abbreviate-file-name root))
                "")))
    (string-trim (concat (shell-quote-argument (executable-find "claude")) " " args))))

(defvar my/ai-enabled t
  "When nil, the AI dock is off: C-SPC opens the plain shell instead.
Toggled with `:ai' / `:noai', and persisted across sessions by `savehist' —
the job `g:AI' did in shada on the nvim side.")

(defun my/ai-on ()
  "Enable the AI dock and open it (`:ai')."
  (interactive)
  (setq my/ai-enabled t)
  (my/toggle-ai))

(defun my/ai-off ()
  "Disable the AI dock and end any running session (`:noai')."
  (interactive)
  (setq my/ai-enabled nil)
  (dolist (buf (seq-filter #'my/ai-buffer-p (buffer-list)))
    (when-let ((win (get-buffer-window buf)))
      (delete-window win))
    (when-let ((proc (get-buffer-process buf)))
      (set-process-query-on-exit-flag proc nil))
    (kill-buffer buf))
  (message "AI off"))

(defun my/toggle-ai ()
  "Toggle a Claude Code session docked at the bottom, rooted at the project."
  (interactive)
  (let* ((buf (get-buffer (my/ai-buffer-name)))
         (win (and buf (get-buffer-window buf))))
    (cond
     (win (delete-window win))
     (buf (pop-to-buffer buf))
     (t
      (unless (executable-find "claude")
        (user-error "`claude' is not on Emacs's PATH"))
      ;; vterm is autoloaded on the `vterm' COMMAND, so its variables do not
      ;; exist until the library loads. The let below READS `vterm-environment',
      ;; which is a void-variable error until then — pull the library in first.
      (require 'vterm)
      (let ((default-directory (my/ai-root))
            (vterm-buffer-name (my/ai-buffer-name))
            ;; Run the CLI as the terminal's program, so quitting Claude closes
            ;; the dock.
            (vterm-shell (my/ai--shell-command default-directory))
            ;; vterm already advertises TERM=xterm-256color; COLORTERM is what
            ;; makes a TUI use its full palette instead of a 16-colour fallback.
            (vterm-environment
             (append '("COLORTERM=truecolor"
                       ;; Never let the TUI capture the mouse: the wheel stays
                       ;; with the buffer, so it scrolls the transcript instead
                       ;; of cycling prompt history. Also set in
                       ;; ~/.claude/settings.json env; this makes the dock
                       ;; independent of that file being read.
                       "CLAUDE_CODE_DISABLE_MOUSE=1"
                       ;; Ghost-text suggestions are drawn with SGR "faint",
                       ;; which libvterm has no attribute for — they render
                       ;; identical to typed text here. Off in this dock only;
                       ;; Claude in alacritty keeps them.
                       "CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=0")
                     vterm-environment)))
        (vterm))))))

(defun my/toggle-dock ()
  "Open the AI session — or, from inside a dock, put that dock away.
The leader is unreachable inside a vterm (SPC goes to the program), so this one
chord has to serve as the way out of whichever terminal you are standing in."
  (interactive)
  (if (or (equal (buffer-name) my/term-buffer-name) (my/ai-buffer-p))
      (delete-window (selected-window))
    (if my/ai-enabled (my/toggle-ai) (my/toggle-shell))))

;;; ---- gdb --------------------------------------------------------------------
;; The reason to try this. `M-x gdb' then accept:  gdb -i=mi a.out
;; Source, locals, registers, stack, breakpoints and program I/O as live
;; windows. The Makefile already builds with -g, so this works today.
(setq gdb-many-windows t
      gdb-show-main t)

(use-package eglot
  :ensure nil                           ; built in since Emacs 29
  :hook ((c-mode c-ts-mode c++-mode c++-ts-mode) . eglot-ensure)
  :init
  ;; Navigation ONLY, and set in :init so it is true BEFORE eglot ever connects.
  ;; `eglot-stay-out-of' keeps it from switching on flymake, so clangd feeds
  ;; xref and nothing ever draws a warning or underline in the buffer.
  (setq eglot-stay-out-of '(flymake)
        eglot-report-progress nil
        eglot-autoshutdown t))

(defun my/main-window ()
  "Window that file buffers belong in: the selected one, unless it is a dock.
Side windows hold transient output; opening a source file into one would both
lose the output and leave the file in a 40%-tall window."
  (cl-flet ((dockish-p (w)
              (or (window-parameter w 'window-side)      ; bottom docks
                  (window-dedicated-p w)                  ; the outline panel etc.
                  (equal (buffer-name (window-buffer w)) "*Ilist*"))))
    (if (dockish-p (selected-window))
        (or (seq-find (lambda (w) (not (dockish-p w))) (window-list nil 'nomini))
            (selected-window))
      (selected-window))))

(defvar my/sticky-dock-buffers '("*compilation*")
  "Docks that survive a gf/gd jump.
Build output is a worklist — you jump to the first error, fix it, then come back
for the next one. Closing it on the first jump would throw the list away. A
terminal dock has no such role, so it gets out of the way.")

(defvar my/hidden-docks nil
  "Buffers last hidden from the bottom by `my/hide-docks', for `my/toggle-docks'.")

(defun my/bottom-docks ()
  (seq-filter #'my/bottom-dock-p (window-list nil 'nomini)))

(defun my/hide-docks ()
  "Hide the BOTTOM docks, remembering them for `my/toggle-docks'.
Bottom only, so the outline panel on the right is never swept away by a jump."
  (let ((wins (my/bottom-docks)))
    (when wins
      (setq my/hidden-docks (mapcar #'window-buffer wins))
      (mapc #'delete-window wins))))

(defun my/toggle-docks ()
  "SPC t: hide the bottom docks, or bring back the ones last hidden."
  (interactive)
  (if (my/bottom-docks)
      (my/hide-docks)
    (dolist (buf my/hidden-docks)
      (when (buffer-live-p buf) (display-buffer buf)))))

(defun my/goto-file-at-point ()
  "Open the file named at point, honouring a trailing :LINE. Never prompts.
`find-file-at-point' falls back to a \"Find file:\" minibuffer prompt when there
is no path under the cursor. That fallback is useless from gf — if the cursor is
not on a path, say so and stay put."
  (interactive)
  (require 'ffap)
  (let* ((origin (buffer-name))
         (name (ffap-file-at-point))
         ;; Pull the :LINE off the current line before moving anywhere, since
         ;; the surrounding text is gone once we switch windows. This is what
         ;; makes gf work on `scanner.c:48' in build output.
         (line (and name
                    (save-excursion
                      (beginning-of-line)
                      (when (re-search-forward
                             (concat (regexp-quote (file-name-nondirectory name))
                                     ":\\([0-9]+\\)")
                             (line-end-position) t)
                        (string-to-number (match-string 1)))))))
    (cond
     ((null name) (user-error "No file path under cursor"))
     ((not (file-exists-p name)) (user-error "No such file: %s" name)))
    ;; Open in the main window, never in the dock we may be standing in — the
    ;; dock stays put with its output intact, exactly like the nvim watcher.
    (select-window (my/main-window))
    (find-file name)
    (when line
      (goto-char (point-min))
      (forward-line (1- line)))
    ;; Give the frame to the file — unless we jumped out of the build output,
    ;; which stays put so the remaining errors are still there to walk.
    (unless (member origin my/sticky-dock-buffers)
      (my/hide-docks))))

(defun my/toggle-doc ()
  "Show the doc for the symbol at point in the bottom dock, or close it if showing.
Pressing K a second time is the way to dismiss it — no need to focus the window."
  (interactive)
  (let ((win (get-buffer-window "*eldoc*")))
    (if win
        (quit-window nil win)
      (eldoc t))))

;; evil-collection rebinds K to `eldoc-doc-buffer' the moment clangd attaches
;; (evil-collection-eglot.el). Claim it back per-buffer from the same hook, so
;; ours wins regardless of load order.
(add-hook 'eglot-managed-mode-hook
          (lambda () (evil-local-set-key 'normal (kbd "K") #'my/toggle-doc)))

;; clangd without a compile database only knows what the current file #includes,
;; so from main.c a jump to scanToken lands on the PROTOTYPE in scanner.h. That is
;; never what you want for behaviour: definitions live in .c files. When a jump
;; lands on a prototype in a header, continue to the definition, found the way
;; the nvim symbol_goto did it — a column-0 `... name(' in a .c file that is not
;; itself a prototype. Types, enums and macros in headers are left alone: the
;; header IS their definition.
(defun my/prototype-at-point-p (name)
  "Non-nil if the current line is a function prototype for NAME."
  (save-excursion
    (beginning-of-line)
    (looking-at (concat "^[ \t]*[A-Za-z_][^=;{}]*\\b" (regexp-quote name)
                        "[ \t]*(.*)[ \t]*;[ \t]*$"))))

(defun my/find-c-definition (name)
  "(FILE . LINE) of function NAME's definition in the project's .c files, or nil.
Definitions start at column 0 (K&R style), which also rules out call sites."
  (let* ((default-directory (my/project-root))
         (out (shell-command-to-string
               (format "rg --no-heading --with-filename --line-number --sort path -g '*.c' %s ."
                       (shell-quote-argument (format "^[A-Za-z_].*\\b%s[ \t]*\\(" name))))))
    (catch 'found
      (dolist (l (split-string out "\n" t))
        (when (string-match "^\\([^:]+\\):\\([0-9]+\\):\\(.*\\)$" l)
          (unless (string-match-p ";[ \t]*$" (match-string 3 l))   ; a prototype, keep looking
            (throw 'found (cons (expand-file-name (match-string 1 l))
                                (string-to-number (match-string 2 l))))))))))

(defun my/prefer-definition (&rest _)
  "After a jump lands on a prototype in a header, continue to the definition."
  (when (and buffer-file-name (string-match-p "\\.h\\'" buffer-file-name))
    (let ((name (thing-at-point 'symbol t)))
      (when (and name (my/prototype-at-point-p name))
        (when-let ((def (my/find-c-definition name)))
          (find-file (car def))
          (goto-char (point-min))
          (forward-line (1- (cdr def)))
          (when (search-forward name (line-end-position) t)
            (backward-char (length name))))))))
(advice-add 'xref-find-definitions :after #'my/prefer-definition)

(defun my/definition-split ()
  "C-]: open the definition of the symbol at point in a read-only split below.
gd jumps in place; this is for looking without leaving. The split shows an
indirect clone of the file so read-only applies to the split only — the same
file stays editable in the main window. q closes it."
  (interactive)
  (let ((sym (thing-at-point 'symbol t)) target-buf target-pos)
    (unless sym (user-error "No symbol under cursor"))
    (save-window-excursion                 ; resolve without disturbing the layout
      (xref-find-definitions sym)          ; my/prefer-definition advice applies
      (setq target-buf (current-buffer) target-pos (point)))
    (if (not (buffer-file-name target-buf))
        (pop-to-buffer target-buf)         ; several candidates: the xref list
      (let* ((clone (make-indirect-buffer
                     target-buf
                     (generate-new-buffer-name (concat (buffer-name target-buf) " [def]"))
                     t))
             (win (split-window-below)))
        (set-window-buffer win clone)
        (select-window win)
        (goto-char target-pos)
        (recenter)
        (view-mode 1)
        (evil-local-set-key 'normal (kbd "q") #'my/definition-split-close)))))

(defun my/definition-split-close ()
  "Close a definition split and drop its clone."
  (interactive)
  (let ((clone (current-buffer)))
    (when (> (length (window-list nil 'nomini)) 1) (delete-window))
    (kill-buffer clone)))

;; gd tries these in order. xref must come FIRST: it is what reaches clangd.
;; imenu only ever knows the current buffer, so leaving it first shadowed every
;; cross-file jump; and when both missed, the fallback landed on etags, whose
;; "Visit tags table" prompt was the picker that kept appearing.
(with-eval-after-load 'evil
  (setq evil-goto-definition-functions
        '(evil-goto-definition-xref
          evil-goto-definition-imenu
          evil-goto-definition-search))
  ;; q never records a macro (never used). Freed from evil, it falls through to
  ;; the major mode, and every read-only buffer — help, eldoc, man, compilation,
  ;; xref — binds it there to `quit-window'. So q closes the thing you are
  ;; looking at, which is what it was always for.
  (define-key evil-normal-state-map (kbd "q") nil)
  ;; C-] to jump, C-t to come back — vim's tag-stack keys, on xref.
  (dolist (map (list evil-normal-state-map evil-motion-state-map))
    (define-key map (kbd "C-]") #'my/definition-split)
    (define-key map (kbd "C-t") #'xref-go-back)
    (define-key map (kbd "gf")  #'my/goto-file-at-point)))

;; Man pages open in the bottom dock and take focus, like :Man's split in nvim,
;; so j/k scroll it and q closes it without a window hop first.
(setq Man-notify-method 'aggressive)

(defun my/man-at-point ()
  "Open the man page for the word under the cursor. No prompt.
Man's own lookup rules apply, so `printf' finds printf(3) and `std::vector'
finds the stdman page; `q' closes it."
  (interactive)
  (require 'man)
  (let ((entry (Man-default-man-entry)))
    (when (string-empty-p entry)
      (user-error "No word under cursor"))
    (man entry)))

;; M (Shift-m) = man page for the word at point. vim's M (jump to the middle
;; line of the window) is given up for it.
(with-eval-after-load 'evil
  (dolist (map (list evil-normal-state-map evil-motion-state-map))
    (define-key map (kbd "M") #'my/man-at-point)))

;;; ---- git --------------------------------------------------------------------
(use-package magit :commands (magit-status magit-log-current))

;;; ---- vim keys ---------------------------------------------------------------
;; editor.el: the evil layer — `jk' and C-c to normal state, visual-line j/k,
;; targets.el (vendored in lisp/).

(use-package evil
  :init (setq evil-want-keybinding nil
              evil-want-C-u-scroll t
              evil-undo-system 'undo-redo
              ;; Don't pre-fill `:' with the previous ex command as a grey
              ;; hint (and re-run it on a bare RET). vim opens an empty line.
              evil-want-empty-ex-last-command nil)
  :config (evil-mode 1))
(use-package evil-collection :after evil :config (evil-collection-init))
(use-package evil-escape)               ; editor.el configures it

(with-eval-after-load 'evil
  (load (expand-file-name "editor.el" user-emacs-directory))
  ;; C-hjkl between windows, as in nvim. Normal/motion state only — binding
  ;; C-h globally would collide with backspace on terminals that send BS.
  (dolist (map (list evil-normal-state-map evil-motion-state-map))
    (define-key map (kbd "C-h") #'evil-window-left)
    (define-key map (kbd "C-j") #'evil-window-down)
    (define-key map (kbd "C-k") #'evil-window-up)
    (define-key map (kbd "C-l") #'evil-window-right)))

(defface my/unsaved-change-face '((t :inherit region))
  "Face for lines that differ from the file on disk.
Inherits `region', so it is literally the selection colour.")

(defvar-local my/unsaved-change-overlays nil)

(defun my/clear-unsaved-changes ()
  "Remove unsaved-change highlighting from this buffer."
  (interactive)
  (mapc #'delete-overlay my/unsaved-change-overlays)
  (setq my/unsaved-change-overlays nil))
(add-hook 'after-save-hook #'my/clear-unsaved-changes)

(defun my/changed-line-numbers ()
  "Line numbers in this buffer that differ from the file on disk.
Asks diff for the line numbers directly with --new-line-format, rather than
parsing hunk headers out of a normal diff."
  ;; `buffer-file-name' is buffer-local: capture it BEFORE entering the temp
  ;; buffer, where it would be nil and diff would receive no filename.
  (let ((file buffer-file-name)
        (tmp (make-temp-file "emacs-unsaved-"))
        lines)
    (unwind-protect
        (progn
          (write-region nil nil tmp nil 'silent)
          (with-temp-buffer
            (call-process "diff" nil t nil
                          "--old-line-format=" "--new-line-format=%dn\n"
                          "--unchanged-line-format=" file tmp)
            (goto-char (point-min))
            (while (re-search-forward "^[0-9]+$" nil t)
              (push (string-to-number (match-string 0)) lines))))
      (delete-file tmp))
    (nreverse lines)))

(defun my/highlight-unsaved-changes ()
  "Highlight every line that differs from disk, and return the first such line.
Only added and changed lines can be shown — a deleted line has no line left in
the buffer to mark."
  (interactive)
  (my/clear-unsaved-changes)
  (when (and buffer-file-name (buffer-modified-p)
             (file-exists-p buffer-file-name)
             (executable-find "diff"))
    (let ((lines (my/changed-line-numbers)))
      (save-excursion
        (dolist (n lines)
          (goto-char (point-min))
          (forward-line (1- n))
          (let ((ov (make-overlay (line-beginning-position)
                                  (min (point-max) (1+ (line-end-position))))))
            (overlay-put ov 'face 'my/unsaved-change-face)
            (overlay-put ov 'evaporate t)
            (push ov my/unsaved-change-overlays))))
      (car lines))))

(defun my/quit (&optional force)
  "Quit Emacs. Vim semantics: no confirmation when there is nothing to lose.
If every file-visiting buffer is saved, exit immediately — no \"really quit?\",
no prompt about running processes. If one is modified, refuse to quit, name it,
and switch to it so the cursor is already where the work is.
With FORCE (prefix argument, or `:qa!'), discard changes and exit anyway."
  (interactive "P")
  (let ((dirty (unless force
                 (seq-find (lambda (b)
                             (and (buffer-file-name b) (buffer-modified-p b)))
                           (buffer-list)))))
    (if dirty
        (progn
          (switch-to-buffer dirty)
          (let ((first (my/highlight-unsaved-changes)))
            (when first
              (goto-char (point-min))
              (forward-line (1- first)))
            (message "No write since last change: %s%s  (SPC w saves, SPC u SPC Q discards)"
                     (buffer-name dirty)
                     (if my/unsaved-change-overlays
                         (format " — %d changed line(s) highlighted"
                                 (length my/unsaved-change-overlays))
                       ""))))
      ;; Nothing unsaved: leave without asking anything, live terminals included.
      ;; `save-buffers-kill-terminal' is client-aware: under the daemon it
      ;; closes this frame and leaves the daemon (and every dock) running;
      ;; in a standalone emacs it exits as before.
      (let ((confirm-kill-emacs nil)
            (confirm-kill-processes nil))
        (set-buffer-modified-p nil)
        (save-buffers-kill-terminal)))))

(with-eval-after-load 'evil
  (evil-ex-define-cmd "qa"  #'my/quit)
  (evil-ex-define-cmd "quita[ll]" #'my/quit))

(defvar my/edit-history-file "~/.edit_history"
  "Shared with zsh: every file opened, appended newest-last.")

(defun my/edit-history--lines ()
  "Lines of `my/edit-history-file', oldest first; nil if it is unreadable."
  (let ((file (expand-file-name my/edit-history-file)))
    (when (file-readable-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (split-string (buffer-string) "\n" t)))))

(defun my/edit-history-record ()
  "Append this buffer's file to `my/edit-history-file', deduped, newest last.
On `after-save-hook' as well as `find-file-hook', so a file created with SPC .
is recorded once it exists on disk, and saving bumps a file to the top."
  (when-let* ((path (and buffer-file-name (expand-file-name buffer-file-name)))
              ((file-readable-p path))
              ((not (equal path (expand-file-name my/edit-history-file))))
              ((not (string-prefix-p ".zshrc" (file-name-nondirectory path)))))
    (let ((lines (my/edit-history--lines)))
      (unless (equal (car (last lines)) path)   ; already newest: don't rewrite
        (with-temp-file (expand-file-name my/edit-history-file)
          (insert (string-join (append (remove path lines) (list path)) "\n") "\n"))))))
(add-hook 'find-file-hook  #'my/edit-history-record)
(add-hook 'after-save-hook #'my/edit-history-record)

(defun my/text-file-p (file)
  "Non-nil if FILE looks like text — empty, or no NUL byte in the first 4 KB.
The elisp equivalent of the `grep -Iq .' guard in fzf_edit_history, which is
what keeps a.out and *.o out of the list."
  (with-temp-buffer
    (let ((coding-system-for-read 'binary))
      (ignore-errors (insert-file-contents-literally file nil 0 4096)))
    (goto-char (point-min))
    (not (search-forward "\0" nil t))))

(defun my/completing-read-ordered (prompt choices)
  "`completing-read' over CHOICES that keeps their order (newest first).
Vertico would otherwise re-sort, which throws away the recency ranking that is
the whole point of the list."
  (completing-read
   prompt
   (lambda (str pred action)
     (if (eq action 'metadata)
         '(metadata (display-sort-function . identity)
                    (cycle-sort-function . identity))
       (complete-with-action action choices str pred)))
   nil t))

(defun my/edit-history-files (&optional root)
  "Absolute paths from `my/edit-history-file', newest first.
Existing text files only, duplicates removed, and restricted to ROOT if given."
  (let ((lines (or (my/edit-history--lines)
                   (user-error "No %s" my/edit-history-file)))
        (seen (make-hash-table :test #'equal))
        out)
    (dolist (f (reverse lines))
      (setq f (string-trim f))
      (when (and (not (string-empty-p f))
                 (not (gethash f seen))
                 (file-regular-p f)
                 (or (null root) (string-prefix-p root f))
                 (my/text-file-p f))
        (puthash f t seen)
        (push f out)))
    (nreverse out)))

(defun my/edit-history ()
  "Open a recently edited file — the same list zsh offers on ^S.
Newest first, existing text files only, and inside a repo restricted to that
repo and shown relative to its root."
  (interactive)
  (let* ((root (let ((d (locate-dominating-file default-directory ".git")))
                 (and d (expand-file-name d))))
         (files (my/edit-history-files root))
         (cands (mapcar (lambda (f) (cons (if root (file-relative-name f root) f) f)) files)))
    (unless cands (user-error "No usable entries in %s" my/edit-history-file))
    (let ((path (cdr (assoc (my/completing-read-ordered "Recent file: " (mapcar #'car cands))
                            cands))))
      (select-window (my/main-window))
      (find-file path))))

(defface my/yank-flash-face '((t :inherit region :extend t))
  "Flash for yanked text. Inherits `region', so it is exactly the visual-mode
colour — the same thing nvim's highlight-on-yank does with the Visual group.
`:extend t' is stated explicitly because it is the one face attribute Emacs
does NOT inherit: without it the highlight stops at each line's last character
and skips blank lines, so a multi-line yank flashes as a broken comb instead
of a solid block.")

(defvar my/yank-flash-duration 0.15
  "Seconds the yank flash stays up. nvim's TextYankPost default is 150 ms.")

(defun my/yank-flash (beg end &rest _)
  "Briefly highlight BEG..END in the selection colour."
  (let ((ov (make-overlay beg end)))
    (overlay-put ov 'face 'my/yank-flash-face)
    (overlay-put ov 'priority 1000)
    (run-with-timer my/yank-flash-duration nil #'delete-overlay ov)))

;; Every yank — yy, yw, yiw, Y, visual y — goes through the `evil-yank'
;; operator, so one piece of advice covers them all.
(advice-add 'evil-yank :after #'my/yank-flash)

;;; ---- header line: path relative to the repo root ------------------------------
(defun my/repo-relative-path ()
  "REPO/path/to/file — the repo's directory name, then the path within it.
Outside a repo, the abbreviated absolute path."
  (when buffer-file-name
    (let ((root (locate-dominating-file buffer-file-name ".git")))
      (if root
          (let ((root (expand-file-name root)))
            (concat (file-name-nondirectory (directory-file-name root)) "/"
                    (file-relative-name buffer-file-name root)))
        (abbreviate-file-name buffer-file-name)))))

(defun my/set-header-line ()
  "Show the repo-relative path at the top of every file buffer."
  (when buffer-file-name
    (setq header-line-format (list " " (my/repo-relative-path)))))
(add-hook 'find-file-hook #'my/set-header-line)

;;; ---- source <-> header --------------------------------------------------------
(defvar my/source-header-twins
  '(("c" "h") ("h" "c" "cpp" "cc") ("cpp" "hpp" "h") ("cc" "hh" "h")
    ("hpp" "cpp") ("hh" "cc"))
  "Extension -> candidate twin extensions, most likely first.")

(defun my/toggle-source-header ()
  "Switch between foo.c and foo.h, in the same directory. No prompts.
Opens the twin if it exists; otherwise opens it as a new buffer (on disk once
saved). A header with no twin becomes .cpp if the directory already holds .cpp
files, else .c. (`ff-find-other-file' was not used: with creation enabled it
asks which directory to create in, every time.)"
  (interactive)
  (unless buffer-file-name (user-error "Not visiting a file"))
  (let* ((ext  (file-name-extension buffer-file-name))
         (base (file-name-sans-extension buffer-file-name))
         (dir  (file-name-directory buffer-file-name))
         (alts (cdr (assoc ext my/source-header-twins))))
    (unless alts (user-error "No source/header twin for .%s" ext))
    (let* ((existing (seq-find (lambda (e) (file-exists-p (concat base "." e))) alts))
           (create   (cond (existing nil)
                           ((and (member ext '("h")) (directory-files dir nil "\\.cpp\\'")) "cpp")
                           (t (car alts)))))
      (find-file (concat base "." (or existing create)))
      (when create
        (message "New file %s — on disk when you save" (file-name-nondirectory buffer-file-name))))))

;;; ---- outline: symbols in this file --------------------------------------------
;; imenu is the built-in equivalent of aerial.nvim's data: an index of the
;; functions and types in the current file, fed by clangd via eglot when it is
;; attached and by c-mode's own parser otherwise. imenu-list is the aerial-style
;; view of it: a persistent panel on the right that tracks the cursor.
(setq imenu-max-item-length 120)

(use-package imenu-list
  :commands (imenu-list-smart-toggle imenu-list-show)
  :init
  (setq imenu-list-position 'right
        imenu-list-size 0.22
        imenu-list-auto-resize nil
        imenu-list-focus-after-activation nil   ; stay in the code
        imenu-list-idle-update-delay 0.3)       ; index rebuild after an edit
  :config
  ;; The highlight follows the cursor IMMEDIATELY, on every command, against
  ;; the cached index (sub-millisecond). Only the rebuild waits for idle time.
  ;; Without this the panel trailed the cursor by the whole idle delay, which
  ;; read as lag.
  (defun my/imenu-list-follow ()
    (when (and (get-buffer-window imenu-list-buffer-name)
               (eq (current-buffer) imenu-list--displayed-buffer)
               imenu-list--imenu-entries)
      (ignore-errors (imenu-list--show-current-entry))))
  (add-hook 'post-command-hook #'my/imenu-list-follow)

  ;; The panel belongs to the buffer it outlines: closing that buffer's window
  ;; (SPC q) or killing the buffer (SPC b d) closes the panel with it.
  (defun my/imenu-list-close-if-orphaned (&rest _)
    (when (and (get-buffer-window imenu-list-buffer-name)
               (eq (current-buffer) imenu-list--displayed-buffer))
      (ignore-errors (imenu-list-quit-window))))
  (add-hook 'kill-buffer-hook #'my/imenu-list-close-if-orphaned)
  (advice-add 'evil-quit :before #'my/imenu-list-close-if-orphaned)

  ;; Colours: imenu-list ships gold/green/blue/orange per nesting depth with
  ;; bold-underlined headers. Match the code buffer instead — symbols in the
  ;; plain foreground, category headers (Function, Struct, Class) in comment
  ;; grey, and the current line highlighted like hl-line.
  (dolist (f '(imenu-list-entry-face imenu-list-entry-face-0 imenu-list-entry-face-1
               imenu-list-entry-face-2 imenu-list-entry-face-3))
    (set-face-attribute f nil :foreground "#e0e2ea" :weight 'normal :underline nil))
  (dolist (f '(imenu-list-entry-subalist-face-0 imenu-list-entry-subalist-face-1
               imenu-list-entry-subalist-face-2 imenu-list-entry-subalist-face-3))
    (set-face-attribute f nil :foreground "#9b9ea4" :weight 'normal :underline nil))
  ;; imenu-list rebuilds the whole index every time point has moved and the
  ;; idle timer fires — and with eglot that rebuild is a BLOCKING request to
  ;; clangd. A j/k plus a pause was a synchronous LSP round-trip: the latency.
  ;; Rebuild only when the text has changed; a cursor move just re-highlights
  ;; against the cached index.
  (defvar-local my/imenu-list-tick nil)
  (defun my/imenu-list-rescan-if-changed (orig)
    (let ((tick (buffer-chars-modified-tick)))
      (unless (and imenu--index-alist (eql tick my/imenu-list-tick))
        (setq my/imenu-list-tick tick)
        (funcall orig))))
  (advice-add 'imenu-list-rescan-imenu :around #'my/imenu-list-rescan-if-changed))

;; Current function in the mode line — aerial's breadcrumb, built in.
(which-function-mode 1)

(defun my/delete-this-file ()
  "Delete the file this buffer is visiting, after a y/n, and close the buffer."
  (interactive)
  (unless buffer-file-name (user-error "Not visiting a file"))
  (let ((file buffer-file-name))
    (when (y-or-n-p (format "Delete %s? " (abbreviate-file-name file)))
      (delete-file file)
      (set-buffer-modified-p nil)
      (kill-buffer)
      (message "Deleted %s" (abbreviate-file-name file)))))

;;; ---- projects ----------------------------------------------------------------
;; project.el, built in: every git repo is a project. The list is seeded from
;; ~/Code at startup (non-recursive: direct children, plus funsies/), and grows
;; on its own as you visit repos elsewhere.
(require 'project)
(require 'cl-lib)
(dolist (dir '("~/Code" "~/Code/funsies"))
  (when (file-directory-p dir)
    ;; Quiet: it announces "No projects were found" whenever every repo is
    ;; already known, which is the normal case after the first run.
    (let ((inhibit-message t))
      (project-remember-projects-under dir))))

(defun my/project-open ()
  "Land in the chosen project: its most recently edited file, else a file picker.
Runs after `project-switch-project' has set `default-directory' to the repo.
Same idea as ^N in zsh — you almost always want the file you were last in."
  (interactive)
  (let* ((root (expand-file-name (project-root (project-current t))))
         (recent (car (ignore-errors (my/edit-history-files root)))))
    (if recent (find-file recent) (project-find-file))))
;; A function here means: no menu after picking, just run it.
(setq project-switch-commands #'my/project-open)

;;; ---- visual J/K: move the selected lines ----------------------------------------
(defun my/move-lines (n)
  "Move the selected lines N lines down (negative: up), keeping them selected.
Whole lines always move, whatever the selection's exact columns were."
  (let* ((rb (if (evil-visual-state-p) evil-visual-beginning (region-beginning)))
         (re (if (evil-visual-state-p) evil-visual-end (region-end)))
         (start (save-excursion (goto-char rb) (line-beginning-position)))
         (end   (save-excursion (goto-char re)
                  (when (and (> re rb) (bolp)) (forward-char -1))
                  (line-beginning-position 2)))
         (text  (buffer-substring start end)))
    (when (or (and (< n 0) (= start (point-min)))
              (and (> n 0) (>= end (point-max))))
      (user-error "Can't move further"))
    (unless (string-suffix-p "\n" text) (setq text (concat text "\n")))
    (delete-region start end)
    (goto-char start)
    (forward-line n)
    (let ((ins (point)))
      (insert text)
      (evil-visual-select ins (+ ins (length text) -1) 'line))))

(defun my/move-lines-down () (interactive) (my/move-lines 1))
(defun my/move-lines-up   () (interactive) (my/move-lines -1))

;; Visual J was evil-join (which is what ate the line below), K was lookup.
(with-eval-after-load 'evil
  (define-key evil-visual-state-map (kbd "J") #'my/move-lines-down)
  (define-key evil-visual-state-map (kbd "K") #'my/move-lines-up))

;;; ---- SPC leader -------------------------------------------------------------
(use-package general
  :after evil
  :config
  (general-create-definer leader!
    :states '(normal visual motion) :keymaps 'override :prefix "SPC")
  (leader!
    "SPC" '(execute-extended-command :which-key "M-x")
    "."   '(find-file                :which-key "find file")
    ","   '(switch-to-buffer         :which-key "switch buffer")
    ;; vim parity: :w and :q on the leader. Window commands keep their native
    ;; vim home on the C-w prefix (C-w s / v / o / c), plus C-hjkl to move.
    "w"   '(save-buffer              :which-key "write (:w)")
    "q"   '(evil-quit                  :which-key "close buffer/window (:q)")
    "Q"   '(my/quit                    :which-key "quit Emacs (:qa)")
    "W"   '(evil-window-map          :which-key "window")
    ;; build + errors  (the watcher)
    "c"   '(:ignore t                :which-key "compile")
    "cc"  '(my/compile-project       :which-key "make")
    "cr"  '(recompile                :which-key "recompile")
    "cn"  '(my/next-result           :which-key "next error")
    "cp"  '(my/previous-result       :which-key "prev error")
    "ct"  '(my/toggle-auto-compile   :which-key "build-on-save toggle")
    ;; debug
    "d"   '(gdb                      :which-key "gdb")
    ;; git
    "g"   '(magit-status             :which-key "magit")
    ;; file / buffer
    "f"   '(:ignore t                :which-key "file")
    "ff"  '(find-file                :which-key "find")
    "fr"  '(recentf-open             :which-key "recent")
    "fs"  '(save-buffer              :which-key "save")
    "b"   '(:ignore t                :which-key "buffer")
    "bb"  '(switch-to-buffer         :which-key "switch")
    "bd"  '(kill-current-buffer      :which-key "kill")
    ;; search / docs
    "s"   '(:ignore t                :which-key "search")
    "sg"  '(my/rg                    :which-key "ripgrep project")
    "sf"  '(my/edit-history          :which-key "recent files (^S list)")
    "sw"  '(my/rg-word-at-point      :which-key "ripgrep word at point")
    "e"   '(my/toggle-source-header  :which-key "source <-> header")
    "o"   '(imenu-list-smart-toggle  :which-key "outline panel")
    ;; projects
    "p"   '(project-switch-project   :which-key "switch project")
    "fp"  '(project-find-file        :which-key "find file in project")
    "m"   '(man                      :which-key "man page")
    ;; shell / windows
    "'"   '(my/toggle-shell            :which-key "shell (toggle)")
    "t"   '(my/toggle-docks            :which-key "toggle bottom strip")
    "z"   '(my/toggle-shell-zoom        :which-key "zoom terminal dock")
    "a"   '(my/toggle-ai                 :which-key "claude code")
    "v"   '(my/toggle-build              :which-key "build output")
    ;; help / quit
    "h"   '(help-command             :which-key "help")))

;;; init.el ends here
