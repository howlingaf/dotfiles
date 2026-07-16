;;; cpp.el --- a standalone C++ scratch REPL -*- lexical-binding: t; -*-
;; A scratch .cpp you jump to from anywhere with "-", compile+run with C-'.
;; Compile AND run are async (Emacs never freezes) and a watchdog kills a
;; runaway program after `my/cpp-run-timeout'. A precompiled <bits/stdc++.h>
;; (built once in the background) roughly halves compile time.
;; Lifted from the old Doom pdf-notes.el, stripped of all the PDF pairing.
;; Needs MinGW g++ (found at C:/msys64/mingw64/bin on this machine).

(require 'seq)

(defvar my/cpp-repl-dir (expand-file-name "~/.cache/cpp-repl/")
  "Where the scratch .cpp / .exe / PCH live.")
(defvar my/cpp-mingw-path
  (or (and (executable-find "g++")
           (directory-file-name (file-name-directory (executable-find "g++"))))
      "C:/msys64/mingw64/bin")
  "Directory containing g++.exe (auto-located on PATH, else the MinGW default).")
(defvar my/cpp-run-timeout 10
  "Seconds before a running program is killed, so infinite loops can't freeze Emacs.")
(defvar my/cpp-flags '("-std=c++23" "-O2" "-Wall" "-Wl,--stack,268435456")
  "g++ flags. Includes a 256MB linker stack so deep recursion / big local arrays
don't stack-overflow (Windows' default ~1MB stack crashes with exit 253 =
STATUS_STACK_OVERFLOW). `my/cpp--pch-flags' strips -W... (incl. this -Wl flag)
for the PCH build, which only needs the -std/-O subset.")
(defvar my/cpp-pch-dir (expand-file-name "pch" my/cpp-repl-dir)
  "Holds the precompiled <bits/stdc++.h> so compiles skip reparsing the STL.")
(defvar my/cpp--pch-building nil)

(defun my/cpp--gxx () (expand-file-name "g++.exe" my/cpp-mingw-path))
(defun my/cpp--pch-file () (expand-file-name "bits/stdc++.h.gch" my/cpp-pch-dir))

(defun my/cpp--stdcxx-header ()
  "Locate this g++'s system bits/stdc++.h, or nil."
  (let ((inc (expand-file-name "../include/c++" my/cpp-mingw-path)))
    (or (car (file-expand-wildcards (expand-file-name "*/*/bits/stdc++.h" inc)))
        (car (file-expand-wildcards (expand-file-name "*/bits/stdc++.h" inc))))))

(defun my/cpp--pch-flags ()
  (seq-remove (lambda (f) (string-prefix-p "-W" f)) my/cpp-flags))

(defun my/cpp--build-pch (&optional force)
  "Build the <bits/stdc++.h> precompiled header ASYNC, once, if missing or FORCE.
While it builds, compiles fall back to the (slower) system header."
  (let ((gch (my/cpp--pch-file))
        (hdr (my/cpp--stdcxx-header)))
    (when (and hdr (not my/cpp--pch-building) (or force (not (file-exists-p gch))))
      (setq my/cpp--pch-building t)
      (make-directory (file-name-directory gch) t)
      (let ((process-environment
             (cons (concat "PATH=" my/cpp-mingw-path ";" (getenv "PATH"))
                   process-environment)))
        (make-process
         :name "cpp-pch" :noquery t :connection-type 'pipe
         :buffer (get-buffer-create " *cpp-pch*")
         :command (append (list (my/cpp--gxx)) (my/cpp--pch-flags)
                          (list "-x" "c++-header" hdr "-o" gch))
         :sentinel (lambda (p _e)
                     (unless (process-live-p p)
                       (setq my/cpp--pch-building nil)
                       (message "C++ precompiled header %s"
                                (if (and (zerop (process-exit-status p))
                                         (file-exists-p gch))
                                    "ready ✓ (compiles ~2× faster now)"
                                  "build failed")))))))))

(defun my/cpp-rebuild-pch ()
  "Rebuild the precompiled header — after a g++ upgrade or a `my/cpp-flags' change."
  (interactive)
  (message "Building C++ precompiled header…")
  (my/cpp--build-pch t))

(defun my/cpp--output ()
  "Get/create the *C++ output* buffer: read-only, q quits, evil-navigable.
special-mode gives read-only + j/k/scroll; we bind q -> quit-window explicitly
so evil's macro-record q doesn't shadow it."
  (let ((buf (get-buffer-create "*C++ output*")))
    (with-current-buffer buf
      (unless (derived-mode-p 'special-mode)
        (special-mode)
        (when (fboundp 'evil-local-set-key)
          (dolist (state '(normal motion))
            (evil-local-set-key state (kbd "q") #'quit-window)))))
    buf))

(defun my/cpp--run-exe (exe out &optional input)
  "Run EXE async, streaming stdout into OUT, killing it after `my/cpp-run-timeout'.
If INPUT (a string) is non-nil it's fed to the program's stdin; either way stdin
is then closed so a program reading cin can't block forever.
A custom filter inserts with `inhibit-read-only' since OUT is read-only."
  (let* ((process-environment
          (cons (concat "PATH=" my/cpp-mingw-path ";" (getenv "PATH"))
                process-environment))
         (killed nil)
         (proc (make-process
                :name "cpp-run" :buffer out :command (list exe)
                :connection-type 'pipe :noquery t
                :filter (lambda (p str)
                          (when (buffer-live-p (process-buffer p))
                            (with-current-buffer (process-buffer p)
                              (let ((inhibit-read-only t))
                                (goto-char (point-max))
                                (insert str)))))))
         (timer (run-at-time my/cpp-run-timeout nil
                             (lambda ()
                               (when (process-live-p proc)
                                 (setq killed t) (kill-process proc))))))
    (when (and input (> (length input) 0))
      (process-send-string proc input))
    (process-send-eof proc)              ; close stdin so cin can't hang the run
    (set-process-sentinel
     proc
     (lambda (p event)
       (unless (process-live-p p)
         (cancel-timer timer)
         (when (buffer-live-p out)
           (with-current-buffer out
             (let ((inhibit-read-only t))
               (goto-char (point-max))
               (insert (if killed
                           (format "\n[killed — exceeded %ss]\n" my/cpp-run-timeout)
                         (format "\n[%s]\n" (string-trim event))))))))))))

(defun my/cpp--after-compile (rc errs exe out &optional input)
  "Compile finished with status RC and output ERRS; show errors or run EXE.
INPUT, if non-nil, is fed to the program's stdin (a Codeforces test case)."
  (when (buffer-live-p out)
    (with-current-buffer out
      (let ((inhibit-read-only t))
        (erase-buffer)
        (cond ((/= rc 0)
               (insert (format "✗ compile failed (rc %s)\n\n%s" rc errs)))
              (t (unless (string-empty-p (string-trim errs)) (insert errs "\n"))
                 (insert (if input "─── output (stdin: test case) ───\n"
                           "─── output ───\n"))
                 (goto-char (point-max))
                 (my/cpp--run-exe exe out input)))
        (goto-char (point-min))))))

(defun my/cpp--test-file (&optional f)
  "Hidden test-input file for cpp source F (default current buffer): .{name}.test."
  (let ((f (or f (buffer-file-name))))
    (expand-file-name (concat "." (file-name-nondirectory f) ".test")
                      (file-name-directory f))))

(defun my/cpp--codeforces-p ()
  "Non-nil if a CODEFORCES marker sits in the first few lines (opt into stdin)."
  (save-excursion
    (goto-char (point-min))
    (re-search-forward "CODEFORCES" (line-end-position 3) t)))

(defun my/cpp-run ()
  "Compile the current C++ buffer with MinGW g++ (C++23) and run it (C-')."
  (interactive)
  (when (buffer-file-name) (save-buffer))
  (my/cpp--build-pch)                    ; ensure the PCH exists (async, once)
  (let* ((f (buffer-file-name))
         (exe (concat (file-name-sans-extension f) ".exe"))
         (out (my/cpp--output))
         ;; Codeforces mode: a CODEFORCES marker up top feeds the hidden
         ;; .{name}.test file (if it exists) to the program's stdin.
         (tf (my/cpp--test-file f))
         (input (when (and (my/cpp--codeforces-p) (file-exists-p tf))
                  (with-temp-buffer (insert-file-contents tf) (buffer-string))))
         ;; only add -I once the PCH exists, else g++ warns about a missing dir
         (iflags (when (file-exists-p (my/cpp--pch-file))
                   (list (concat "-I" my/cpp-pch-dir))))
         (cbuf (generate-new-buffer " *cpp-compile*"))
         (process-environment
          (cons (concat "PATH=" my/cpp-mingw-path ";" (getenv "PATH"))
                process-environment)))
    (with-current-buffer out (let ((inhibit-read-only t)) (erase-buffer) (insert "compiling…\n")))
    (display-buffer out '((display-buffer-below-selected) (window-height . 0.32)))
    (make-process
     :name "cpp-compile" :noquery t :connection-type 'pipe :buffer cbuf
     :command (append (list (my/cpp--gxx)) my/cpp-flags iflags (list f "-o" exe))
     :sentinel (lambda (p _e)
                 (unless (process-live-p p)
                   (let ((rc (process-exit-status p))
                         (errs (with-current-buffer cbuf (buffer-string))))
                     (kill-buffer cbuf)
                     (my/cpp--after-compile rc errs exe out input)))))))

;;; --- the scratch REPL you jump to --------------------------------------------
(defvar my/cpp-scratch-file (expand-file-name "scratch.cpp" my/cpp-repl-dir)
  "The single shared C++ scratch buffer.")

(defun my/cpp-edit-test ()
  "Open the hidden test-input file (.{name}.test) for this C++ buffer (C-_).
Put a `// CODEFORCES' comment up top and this file is fed to stdin on C-'."
  (interactive)
  (unless (buffer-file-name) (user-error "Not visiting a C++ file"))
  (find-file (my/cpp--test-file)))

(defun my/cpp--setup-scratch ()
  "Per-buffer setup for the scratch: line numbers, centering, C-' run, C-_ test."
  (setq-local display-line-numbers t)    ; absolute lines (compile errors cite them)
  ;; center the cursor line like prose (no margin — same as everywhere now)
  (when (and (fboundp 'my/typewriter-mode) (not (bound-and-true-p my/typewriter-mode)))
    (my/typewriter-mode 1))
  ;; C-' compiles+runs, C-_ edits the test case — in every state (C-c stays free
  ;; as the insert→normal escape).
  (when (fboundp 'evil-local-set-key)
    (dolist (state '(normal insert visual))
      (evil-local-set-key state (kbd "C-'") #'my/cpp-run)
      (evil-local-set-key state (kbd "C-_") #'my/cpp-edit-test)))
  (local-set-key (kbd "C-'") #'my/cpp-run)
  (local-set-key (kbd "C-_") #'my/cpp-edit-test))

(defun my/cpp-repl ()
  "Jump to the C++ scratch REPL from anywhere (\"-\"); create it if new.
C-' compiles + runs it."
  (interactive)
  (make-directory my/cpp-repl-dir t)
  (let ((fresh (not (file-exists-p my/cpp-scratch-file))))
    (find-file my/cpp-scratch-file)
    (when (and fresh (= (buffer-size) 0))
      (insert "#include <bits/stdc++.h>\nusing namespace std;\n\nint main() {\n    \n}\n")
      (goto-char (point-min)) (forward-line 4) (end-of-line)
      (save-buffer))
    (my/cpp--setup-scratch)
    (when (fboundp 'evil-normal-state) (evil-normal-state))))

;; Apply the setup to an already-open scratch on (re)load, so a live SPC R takes
;; effect without needing to re-jump with "-".
(when-let ((buf (get-file-buffer my/cpp-scratch-file)))
  (with-current-buffer buf (my/cpp--setup-scratch)))

;; "-" jumps to the REPL from anywhere. Overrides evil's rarely-used "-" motion;
;; dired's own "-" (up-directory) still wins there since its map has priority.
(with-eval-after-load 'evil
  (define-key evil-normal-state-map (kbd "-") #'my/cpp-repl))

(provide 'cpp)
;;; cpp.el ends here
