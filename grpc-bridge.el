;;; grpc-bridge.el --- Emacs RPC bridge package entry (emacs-rpc-bridge module) -*- lexical-binding: t; -*-

;; Author: Zhibin Huang
;; Version: 0.1.0
;; Package-Requires: ((emacs "31.1"))
;; Keywords: extensions, rpc

;;; Commentary:

;; Quelpa/ELPA entry point for the emacs-grpc-ext repository, which is
;; installed as the `grpc-bridge' package (dotspacemacs-additional-packages
;; recipe: `(grpc-bridge :location (recipe :fetcher github-ssh :repo
;; "lesliebinbin/emacs-grpc-ext" :files ("*")))').  The repo's main file
;; lives at the repository root under the package name, mirroring how
;; emacs-jupyter-eval packages `jupyter-eval'.
;;
;; All bridge functionality lives in lisp/emacs-rpc-bridge.el (feature
;; emacs-rpc-bridge); this file only requires it from its own directory and
;; owns the one thing a package install cannot do by itself: the native
;; module (C++/gRPC) is not shipped as elisp.  On first require, when the
;; module has not been built yet, prompt to build it with `mise build'
;; (the emacs-jupyter-eval pattern: noninteractive runs just report the
;; command; interactive runs offer to build in-place).  Loading this file
;; never starts the bridge: call `emacs-rpc-bridge-start' explicitly.

;;; Code:

;; Directory of this file.  Captured the emacs-jupyter-eval way so the
;; const survives byte-compilation, source checkouts, and package installs
;; (quelpa keeps the repo tree, so `build/' lands next to `lisp/').
(defconst grpc-bridge--directory
  (file-name-directory
   (or (and (boundp 'byte-compile-current-file)
            byte-compile-current-file
            (string-match-p "/grpc-bridge\\.elc?$" byte-compile-current-file)
            byte-compile-current-file)
       (and load-file-name
            (string-match-p "/grpc-bridge\\.elc?$" load-file-name)
            load-file-name)
       buffer-file-name)))
(defconst grpc-bridge--root-directory
  (file-name-as-directory (directory-file-name grpc-bridge--directory)))
(defconst grpc-bridge--module-file
  (expand-file-name "build/libemacs-rpc-bridge.so" grpc-bridge--root-directory)
  "Compiled module of the package (built in-place by `mise build').")

(defun grpc-bridge--module-built-p ()
  "Non-nil when the native module is already loaded or built."
  (or (fboundp 'emacs-rpc-bridge-native-start)
      (file-exists-p grpc-bridge--module-file)))

(defun grpc-bridge--ensure-module ()
  "Build the native module on first require when it is missing.

Mirrors emacs-jupyter-eval's dependency check: noninteractive runs
(home-managed batch scripts, CI) just report the build command; interactive
runs prompt and build in place with `mise build'."
  (unless (grpc-bridge--module-built-p)
    (if noninteractive
        (message
         "grpc-bridge: native module not built; run: mise --cd %s build"
         grpc-bridge--root-directory)
      (when (y-or-n-p
             (format
              "grpc-bridge: native module is missing in %s. Build it now with `mise build'? "
              grpc-bridge--root-directory))
        (message "grpc-bridge: building the native module...")
        (let ((default-directory grpc-bridge--root-directory))
          (unless (zerop (call-process "mise" nil (get-buffer-create "*grpc-bridge-build*")
                                       nil "build"))
            (user-error "grpc-bridge build failed; see buffer *grpc-bridge-build*")))
        (unless (grpc-bridge--module-built-p)
          (user-error "`mise build' finished but no module at %s"
                      grpc-bridge--module-file))))))

(defun grpc-bridge--load-engine ()
  "Load the adapter engine, then ensure the native module exists.

Both steps run at load time, but they live in a function on purpose: the
byte compiler evaluates top-level `require' forms at compile time (to pick
up macros), where the defconsts above are not bound yet -- a plain call is
only compiled, never executed at compile time."
  (require 'emacs-rpc-bridge
           (expand-file-name "lisp/emacs-rpc-bridge.el" grpc-bridge--root-directory))
  (grpc-bridge--ensure-module))

;; First require: load the adapter engine (cheap: no module load, no bridge
;; start), then make sure the native module exists -- prompting to build it
;; on first require, per the package contract in the Commentary.
(grpc-bridge--load-engine)

(provide 'grpc-bridge)
;;; grpc-bridge.el ends here
