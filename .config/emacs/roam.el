;;; roam.el --- org-roam zettelkasten + graph, synced to the server -*- lexical-binding: t; -*-
;; Local .org notes in ~/org-roam (so the graph/DB are fast), two-way synced to
;; ash-1 via `rclone bisync' on STARTUP and on SAVE. org-roam-ui is the
;; interactive node graph in the browser. Cross-machine: clone the same rclone
;; remote on Linux/Mac and this same config syncs there too.

(defvar my/org-roam-dir (expand-file-name "~/howlingaf-notes/")
  "Local org-roam notes folder (the thing that gets synced).")

;;; --- org-roam ----------------------------------------------------------------
(use-package org-roam
  :init
  (setq org-roam-directory my/org-roam-dir
        ;; Emacs 30 has built-in SQLite — no compiled emacsql backend to build.
        org-roam-database-connector 'sqlite-builtin
        ;; keep the DB OUT of the synced folder: it's a local, rebuildable index.
        org-roam-db-location (expand-file-name "org-roam.db" user-emacs-directory)
        org-roam-completion-everywhere t)
  :config
  (org-roam-db-autosync-mode 1))       ; keep the DB current as you edit

;;; --- org-roam-ui (the graph) -------------------------------------------------
(use-package org-roam-ui
  :after org-roam
  :init (setq org-roam-ui-sync-theme t
              org-roam-ui-follow t          ; graph highlights the note you're in
              org-roam-ui-update-on-save t
              org-roam-ui-open-on-start nil))

;; EAF = an embedded Chromium (QtWebEngine) view in an Emacs window, via a Python
;; sidecar. The only way to EMBED the interactive graph on Windows (no xwidgets).
;; Isolated in ~/.eaf with its own venv python — undo = delete ~/.eaf + this.
;; Lazy-loaded on first graph open so it costs nothing at startup.
(defvar my/eaf-dir (expand-file-name "~/.eaf/emacs-application-framework/"))

(defun my/eaf-ensure ()
  "Load EAF on demand; non-nil when the embedded browser is available."
  (when (file-directory-p my/eaf-dir)
    (add-to-list 'load-path my/eaf-dir)
    (setq eaf-python-command
          (expand-file-name (if (eq system-type 'windows-nt)
                                "~/.eaf/venv/Scripts/python.exe"
                              "~/.eaf/venv/bin/python")))
    ;; EAF's eaf--emacs-program-name defvar runs replace-regexp-in-string on
    ;; (process-attributes)'s `comm', which is nil on Windows -> arrayp-nil crash.
    ;; Pre-bind it so EAF's defvar is a no-op.
    (defvar eaf--emacs-program-name "emacs")
    (when (and (require 'eaf nil t) (require 'eaf-browser nil t))
      ;; eaf-mode's BODY sets mode-line-format from eaf-mode-line-format; its
      ;; HOOK runs after, so strip modeline + header-line there to be sure.
      (setq eaf-mode-line-format nil)
      (add-hook 'eaf-mode-hook #'my/eaf-strip-chrome)
      (my/roam-graph--ensure-css)          ; hide org-roam-ui's gear + header bar
      (fboundp 'eaf-open-browser))))

(defun my/eaf-strip-chrome ()
  "Remove the modeline + header-line from EAF buffers (the graph widget)."
  (setq-local mode-line-format nil header-line-format nil))

;; Patch two things into org-roam-ui's served index.html for the embedded widget:
;;   1. CSS hiding its chrome — the Settings gear (top-left) + the file-viewer
;;      header bar (top-right X).
;;   2. A tiny script that forces org-roam-ui's mouse config in localStorage so a
;;      single click OPENS THE NODE IN EMACS: `follow:"click"' is the action that
;;      sends {command:"open"} over the websocket; `preview:"never"' stops the
;;      in-browser preview from shadowing it (same "click" trigger, earlier case).
;; Idempotent + self-healing: if a package reinstall regenerates index.html, this
;; re-adds both on the next graph open. Undo = delete the two marker tags.
(defvar my/roam-graph-inject
  (concat
   "<style id=\"my-roam-graph-css\">"
   "button[aria-label=\"Settings\"]{display:none!important}"
   ".headerBar{display:none!important}"
   "</style>"
   "<script id=\"my-roam-graph-js\">(function(){try{var k=\"mouse\",c={};"
   "try{c=JSON.parse(localStorage.getItem(k))||{}}catch(e){}"
   "c.follow=\"click\";c.preview=\"never\";"
   "localStorage.setItem(k,JSON.stringify(c));}catch(e){}})();</script>")
  "HTML injected into org-roam-ui's <head>: chrome-hiding CSS + click-to-open-in-
Emacs behavior. The <script> must run before the app so it seeds localStorage.")

(defun my/roam-graph--ensure-css ()
  "Ensure `my/roam-graph-inject' is present in org-roam-ui's index.html."
  (let ((html (ignore-errors
                (expand-file-name
                 "out/index.html"
                 (file-name-directory (locate-library "org-roam-ui"))))))
    (when (and html (file-writable-p html))
      (with-temp-buffer
        (insert-file-contents html)
        (goto-char (point-min))
        (unless (search-forward "id=\"my-roam-graph-js\"" nil t)
          (goto-char (point-min))
          (when (search-forward "</head>" nil t)
            (replace-match (concat my/roam-graph-inject "</head>") t t)
            (write-region (point-min) (point-max) html nil 'quiet)))))))

;; When org-roam-ui opens a node (single click in the graph), its default logic
;; can split/hijack whatever window is selected — which is the graph's child
;; frame if you just clicked it. Pin the target to a window on the MAIN frame so
;; the note lands there and the parent frame comes forward, never the widget.
(defun my/roam-graph--target-window (&rest _)
  "Point org-roam-ui's node-open at a window on the graph frame's parent."
  (let ((pf (and (frame-live-p my/roam-graph-frame)
                 (frame-parent my/roam-graph-frame))))
    (when (frame-live-p pf)
      (setq org-roam-ui--window (frame-selected-window pf))
      (select-frame-set-input-focus pf))))
(with-eval-after-load 'org-roam-ui
  (add-hook 'org-roam-ui-before-open-node-functions #'my/roam-graph--target-window))

(defun my/roam-graph--url ()
  "org-roam-ui URL with a cache-buster so EAF always re-fetches the patched
index.html (chrome-hiding CSS + click-to-open JS) instead of a stale copy."
  (format "http://localhost:35901/?t=%d" (random 1000000000)))

(defun my/org-roam-graph ()
  "Show the org-roam-ui graph EMBEDDED in Emacs (full window): EAF (Windows) or
xwidgets (Mac/Linux). Last-resort fallback to the external browser."
  (interactive)
  (require 'org-roam-ui)
  (let* ((url (my/roam-graph--url))
         (fresh (not (bound-and-true-p org-roam-ui-mode)))
         (open (lambda ()
                 (cond
                  ((my/eaf-ensure) (eaf-open-browser url))
                  ((and (featurep 'xwidget-internal) (fboundp 'xwidget-webkit-browse-url))
                   (xwidget-webkit-browse-url url))
                  (t (browse-url url))))))
    (unless (bound-and-true-p org-roam-ui-mode) (org-roam-ui-mode 1))
    (if fresh (run-at-time 1.5 nil open) (funcall open))))

;;; --- persistent graph in a bottom-right child frame --------------------------
(defvar my/roam-graph-frame nil "The pinned bottom-right graph child frame.")
(defvar my/roam-graph-width 700 "Graph child-frame width in pixels.")
(defvar my/roam-graph-height 550 "Graph child-frame height in pixels.")
(defvar my/roam-graph-right 0
  "Pixels between the frame's right edge and the parent's right edge.")
(defvar my/roam-graph-y-offset nil
  "Pixels to shift the frame DOWN from vertical center (negative = up).")
(setq my/roam-graph-y-offset 500)   ; tune here — setq so SPC R re-applies it

(defun my/roam-graph--pos (pf)
  "Return (LEFT . TOP) for the graph frame relative to parent frame PF:
flush right (minus `my/roam-graph-right'), `my/roam-graph-y-offset' below center."
  (cons (max 0 (- (frame-pixel-width pf) my/roam-graph-width my/roam-graph-right))
        (max 0 (+ (/ (- (frame-pixel-height pf) my/roam-graph-height) 2)
                  my/roam-graph-y-offset))))

(defun my/roam-graph--resync ()
  "Nudge EAF to re-sync its Qt overlay onto the (moved/shown) graph frame."
  (when (fboundp 'eaf-monitor-configuration-change)
    (eaf-monitor-configuration-change)))

(defun my/roam-graph-reposition (&rest _)
  "Re-place the graph frame relative to its parent (so it tracks window resizes).
Skips while hidden — `my/roam-graph-show' repositions on the way back up."
  (when (and (frame-live-p my/roam-graph-frame)
             (frame-visible-p my/roam-graph-frame)
             (frame-live-p (frame-parent my/roam-graph-frame)))
    (let ((pos (my/roam-graph--pos (frame-parent my/roam-graph-frame))))
      (set-frame-position my/roam-graph-frame (car pos) (cdr pos))
      (my/roam-graph--resync))))
(add-hook 'window-size-change-functions #'my/roam-graph-reposition)

;; The widget is a PERSISTENT child frame: created + EAF-loaded once, then shown
;; and hidden by toggling frame VISIBILITY. Hiding never tears down EAF, so
;; show/hide is instant and doesn't churn Qt processes — essential for the
;; auto-follow behavior below, which flips it on every buffer switch.
(defun my/roam-graph--create ()
  "Create the graph child frame and load the EAF graph into it (once).
Does not steal focus from the frame you're editing in (PF)."
  (require 'org-roam-ui)
  (unless (my/eaf-ensure) (user-error "EAF unavailable"))
  (let* ((fresh (not (bound-and-true-p org-roam-ui-mode)))
         (pf (selected-frame))
         (pos (my/roam-graph--pos pf))
         (cx (car pos)) (cy (cdr pos)))
    (unless (bound-and-true-p org-roam-ui-mode) (org-roam-ui-mode 1))
    (setq my/roam-graph-frame
          (make-frame
           `((name . "roam-graph")
             (title . "roam-graph")       ; stable OS title for the GlazeWM ignore rule
             (parent-frame . ,pf)
             (width . (text-pixels . ,my/roam-graph-width))
             (height . (text-pixels . ,my/roam-graph-height))
             (left . ,cx) (top . ,cy)
             (minibuffer . nil)
             (undecorated . t)
             (internal-border-width . 0)
             (left-fringe . 0) (right-fringe . 0)
             (vertical-scroll-bars . nil)
             (unsplittable . t) (no-other-frame . t)
             (no-accept-focus . nil)
             (desktop-dont-save . t))))
    ;; the alist left/top doesn't reliably apply to a child frame — set it again
    (set-frame-position my/roam-graph-frame cx cy)
    (run-at-time (if fresh 1.6 0.8) nil
                 (lambda ()
                   (when (frame-live-p my/roam-graph-frame)
                     ;; open EAF in the graph frame WITHOUT leaving focus there
                     (with-selected-frame my/roam-graph-frame
                       (eaf-open-browser (my/roam-graph--url))
                       (my/eaf-strip-chrome))  ; belt-and-suspenders vs eaf-mode-hook
                     (raise-frame my/roam-graph-frame)
                     ;; Pin EAF's "home frame" to the MAIN frame: EAF only runs
                     ;; `eaf-monitor-configuration-change' when the selected frame
                     ;; equals `eaf-emacs-frame'. We drive show/hide/resize from
                     ;; the main frame, so it must be that — otherwise the Qt view
                     ;; never re-positions. (Default is whatever was focused at
                     ;; first boot, which our focus-restore makes racy.)
                     (when (boundp 'eaf-emacs-frame) (setq eaf-emacs-frame pf))
                     (when (frame-live-p pf) (select-frame-set-input-focus pf))
                     ;; EAF's Qt overlay doesn't auto-track the frame — re-sync it
                     ;; a few times as it settles.
                     (dolist (d '(0.4 1.0 2.0))
                       (run-at-time d nil
                                    (lambda ()
                                      (when (frame-live-p my/roam-graph-frame)
                                        (my/roam-graph--resync))))))))))

(defun my/roam-graph-show ()
  "Show the graph widget (creating it on first use), without stealing focus."
  (interactive)
  (if (frame-live-p my/roam-graph-frame)
      (let ((pf (selected-frame)))
        (my/roam-graph-reposition)
        (make-frame-visible my/roam-graph-frame)
        (raise-frame my/roam-graph-frame)
        (my/roam-graph--resync)
        (when (frame-live-p pf) (select-frame-set-input-focus pf)))
    (my/roam-graph--create)))

(defun my/roam-graph-hide ()
  "Hide the graph widget (kept loaded so re-showing is instant)."
  (interactive)
  (when (frame-live-p my/roam-graph-frame)
    (make-frame-invisible my/roam-graph-frame t)))

(defun my/roam-graph-corner ()
  "Toggle the persistent graph widget (flush-right, EAF-rendered)."
  (interactive)
  (if (and (frame-live-p my/roam-graph-frame)
           (frame-visible-p my/roam-graph-frame))
      (my/roam-graph-hide)
    (my/roam-graph-show)))

;;; --- auto-follow: show the widget only while editing an org buffer -----------
;; Always on: the widget tracks whether the active buffer is org — no toggle.
(defvar my/roam-graph-auto--timer nil)

(defun my/roam-graph-auto--apply ()
  "Show/hide the widget to match whether the active buffer is org."
  (setq my/roam-graph-auto--timer nil)
  ;; ignore the minibuffer and focus ON the widget itself (else it fights us)
  (unless (or (window-minibuffer-p (selected-window))
              (and (frame-live-p my/roam-graph-frame)
                   (eq (selected-frame) my/roam-graph-frame)))
    (let ((want (with-current-buffer (window-buffer (selected-window))
                  (derived-mode-p 'org-mode)))
          (shown (and (frame-live-p my/roam-graph-frame)
                      (frame-visible-p my/roam-graph-frame))))
      (cond ((and want (not shown)) (my/roam-graph-show))
            ((and (not want) shown)  (my/roam-graph-hide))))))

(defun my/roam-graph-auto--schedule (&rest _)
  "Debounce `my/roam-graph-auto--apply' to the next 0.2s idle.
No-op where the EAF widget isn't installed (macOS/Linux) so auto-follow never
tries to spawn a graph there — those machines use `SPC n G' (full-window) instead."
  (when (and (file-directory-p my/eaf-dir)
             (not (timerp my/roam-graph-auto--timer)))
    (setq my/roam-graph-auto--timer
          (run-with-idle-timer 0.2 nil #'my/roam-graph-auto--apply))))

(add-hook 'window-buffer-change-functions #'my/roam-graph-auto--schedule)
(add-hook 'window-selection-change-functions #'my/roam-graph-auto--schedule)

;;; --- sync: rclone bisync, async, startup + save ------------------------------
;; executable-find covers Linux/Mac (rclone on PATH); the fallback is the
;; Windows winget shim (this Emacs may predate rclone's PATH entry).
(defvar my/rclone
  (or (executable-find "rclone")
      (expand-file-name "AppData/Local/Microsoft/WinGet/Links/rclone.exe" "~/"))
  "Path to the rclone executable.")
(defvar my/org-roam-remote nil
  "rclone remote:path the notes sync with — machine-local, set in local.el
\(keeps the server path out of the public dotfiles repo, like `vault-remote-root').")
(defvar my/org-roam-sync--timer nil)

(defun my/org-roam-sync (&optional resync)
  "Two-way sync the notes with the server via rclone bisync — async, non-blocking.
On a bisync error (e.g. a missing baseline on a fresh machine) it retries once
with --resync to self-heal. With no concurrent editing, `--conflict-resolve
newer' means the newest edit always wins — no conflict copies."
  (interactive)
  (let* ((local (directory-file-name (expand-file-name my/org-roam-dir)))
         (args (append (list "bisync" local my/org-roam-remote
                             "--exclude" "*.db" "--exclude" "*.db-*"
                             "--conflict-resolve" "newer" "--resilient")
                       (when resync '("--resync")))))
    (make-process
     :name "org-roam-sync" :noquery t :connection-type 'pipe
     :buffer (get-buffer-create "*org-roam-sync*")
     :command (cons my/rclone args)
     :sentinel (lambda (_p e)
                 (when (and (not resync) (string-match-p "abnormally" e))
                   (my/org-roam-sync t))))))   ; recover a broken/absent baseline

(defun my/org-roam-sync--on-save ()
  "Debounced sync ~3s after saving a note inside the roam folder."
  (when (and buffer-file-name
             (string-prefix-p (expand-file-name my/org-roam-dir)
                              (expand-file-name buffer-file-name)))
    (when (timerp my/org-roam-sync--timer) (cancel-timer my/org-roam-sync--timer))
    (setq my/org-roam-sync--timer
          (run-with-idle-timer 3 nil #'my/org-roam-sync))))

(add-hook 'after-save-hook #'my/org-roam-sync--on-save)
;; pull on startup, shortly after launch settles
(run-with-idle-timer 2 nil #'my/org-roam-sync)

(provide 'roam)
;;; roam.el ends here
