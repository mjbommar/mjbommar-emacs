;;; mjb-package.el --- Package set, lockfile, pruning -*- lexical-binding: t -*-

;;; Commentary:
;; The declared package set and the commands that keep it honest.
;;
;; Requirement refs: R-004 (reproducible), R-005 (pruning), R-008 (provenance).
;;
;; An honest limitation, stated up front because R-004 asked for something
;; stronger than is actually achievable here:
;;
;;   MELPA serves only the LATEST build of each package.  It does not keep old
;;   versions.  So a lockfile recording "consult 3.7" cannot be *restored* from
;;   MELPA once consult 3.8 ships -- the 3.7 artifact no longer exists to fetch.
;;   True pinning requires either vendoring the sources, or a package manager
;;   that clones git and checks out a revision (straight/elpaca), or using only
;;   GNU ELPA (which does keep old versions).
;;
;; What is achievable with built-in package.el, and what this implements:
;;   - record the exact installed set and versions in a committed file
;;   - detect drift from it, loudly
;;   - reinstall the recorded NAMES on a clean machine (latest versions)
;;   - prune anything not declared
;;
;; That is reproducible-by-name with detectable drift, not byte-identical
;; reproduction.  See docs/requirements/08 for the amended R-004.

;;; Code:

(require 'package)
(require 'seq)

;;;; Archives and trust (R-008, R-009) -------------------------------------------
;; These take effect when a package is fetched, not when it is activated, so
;; they live here rather than in init.el alongside `package-initialize'.

(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/"))
      ;; Prefer signed GNU/NonGNU ELPA over MELPA when a package is on both.
      package-archive-priorities '(("gnu" . 3) ("nongnu" . 2) ("melpa" . 1))

      ;; Require a valid OpenPGP signature.  The default is `allow-unsigned',
      ;; which checks a signature when one is present and silently accepts the
      ;; package when it is not -- so an archive that stops signing downgrades
      ;; you without a word.
      ;;
      ;; MELPA signs nothing: it builds from upstream git on its own servers,
      ;; so there is no author signature to publish.  Naming it below is an
      ;; accurate statement of where trust stops rather than a loophole, and it
      ;; is deliberately the ONLY entry, so a second unsigned archive would be
      ;; a visible diff.  Exactly one installed package comes from MELPA
      ;; (vterm); the other 16 are signed and were verified on install.
      package-check-signature t
      package-unsigned-archives '("melpa"))

;; `package-refresh-contents' imports Emacs's own keyring into
;; `package-gnupghome-dir' by itself, but only when signature checking is on.
;; Without gpg on PATH verification silently degrades, so say so rather than
;; look like we are checking when we are not.
(unless (executable-find "gpg")
  (message "mjb: gpg not found -- package signatures CANNOT be verified"))

(defun mjb-check-signatures ()
  "Report which installed packages carry a verified signature.
package.el writes NAME-VERSION.signed next to the package directory when it
verified a signature at install time, so this reads evidence rather than
re-asserting policy."
  (interactive)
  (let (signed unsigned)
    (dolist (cell package-alist)
      (let* ((desc (cadr cell))
             (dir (and desc (package-desc-dir desc))))
        (if (and dir (file-exists-p (concat (directory-file-name dir) ".signed")))
            (push (car cell) signed)
          (push (car cell) unsigned))))
    (message "mjb: %d/%d packages signed%s"
             (length signed) (length package-alist)
             (if unsigned (format "; unsigned: %s" (nreverse unsigned)) ""))))

(defvar mjb-packages
  '(vertico orderless marginalia consult corfu cape ; completion: wrap built-ins
    magit diff-hl                                   ; git: essential complexity
    markdown-mode csv-mode                          ; no built-in equivalent
    vterm)                                          ; compiled terminal emulator
  ;; NOTE: no AI packages.  gptel (13,366 lines) and minuet (5,090 + dash
  ;; 3,347 + plz 1,161) are replaced by lisp/mjb-ai.el, which talks to the
  ;; Messages API directly over curl.
  "Every package this configuration installs.
Anything not listed is a transitive dependency.  Adding an entry requires a
comment saying what it does that a built-in cannot.  Note there is no theme
package: the Modus themes ship with Emacs 30 and are built to a measured
contrast ratio, which is what terminal and GUI frames both need.")

(defconst mjb-lockfile
  (expand-file-name "package-lock.eld" user-emacs-directory)
  "Committed record of the installed package set and versions.")

;; Feed `package-autoremove' (R-005).
(setq package-selected-packages mjb-packages)

;;;; Install (R-073: idempotent) ------------------------------------------------

(defun mjb-install-packages ()
  "Install any member of `mjb-packages' that is missing.  Idempotent."
  (interactive)
  (let ((missing (seq-remove #'package-installed-p mjb-packages)))
    (when missing
      (unless package-archive-contents (package-refresh-contents))
      (mapc #'package-install missing))
    (message "mjb: %d declared, %d newly installed"
             (length mjb-packages) (length missing))))

;;;; Lockfile (R-004) -----------------------------------------------------------

(defun mjb--installed-alist ()
  "Return ((NAME . VERSION-STRING) ...) for every activated package."
  (sort
   (mapcar (lambda (cell)
             (let ((desc (cadr cell)))
               (cons (car cell)
                     (and desc (package-version-join (package-desc-version desc))))))
           package-alist)
   (lambda (a b) (string< (symbol-name (car a)) (symbol-name (car b))))))

(defun mjb-write-lockfile ()
  "Record the current package set and versions to `mjb-lockfile'.
Commit the result.  Run this after deliberately adding or upgrading."
  (interactive)
  (let ((data `((generated . ,(format-time-string "%Y-%m-%d"))
                (emacs     . ,emacs-version)
                (declared  . ,mjb-packages)
                (installed . ,(mjb--installed-alist)))))
    (with-temp-file mjb-lockfile
      (insert ";; Generated by M-x mjb-write-lockfile -- do not edit by hand.\n")
      (insert ";; See lisp/mjb-package.el for what this can and cannot guarantee.\n")
      (pp data (current-buffer)))
    (message "mjb: wrote %s (%d packages)"
             (file-name-nondirectory mjb-lockfile)
             (length (alist-get 'installed data)))))

(defun mjb-check-lockfile ()
  "Report drift between `mjb-lockfile' and what is actually installed."
  (interactive)
  (unless (file-exists-p mjb-lockfile)
    (user-error "mjb: no lockfile; run M-x mjb-write-lockfile"))
  (let* ((locked (with-temp-buffer
                   (insert-file-contents mjb-lockfile)
                   (read (current-buffer))))
         (was (alist-get 'installed locked))
         (now (mjb--installed-alist))
         (added   (seq-difference (mapcar #'car now) (mapcar #'car was)))
         (removed (seq-difference (mapcar #'car was) (mapcar #'car now)))
         (changed (seq-filter
                   (lambda (cell)
                     (let ((old (alist-get (car cell) was nil nil #'eq)))
                       (and old (not (equal old (cdr cell))))))
                   now)))
    (if (and (null added) (null removed) (null changed))
        (message "mjb: package set matches the lockfile (%d packages)" (length now))
      (with-output-to-temp-buffer "*mjb package drift*"
        (princ (format "Lockfile generated %s for Emacs %s\n\n"
                       (alist-get 'generated locked) (alist-get 'emacs locked)))
        (when added   (princ (format "ADDED (not in lockfile):\n  %s\n\n" added)))
        (when removed (princ (format "REMOVED (in lockfile, not installed):\n  %s\n\n" removed)))
        (when changed
          (princ "VERSION CHANGED:\n")
          (dolist (c changed)
            (princ (format "  %-16s %s -> %s\n" (car c)
                           (alist-get (car c) was nil nil #'eq) (cdr c)))))
        (princ "\nRun M-x mjb-write-lockfile to accept the current state.\n")))))

;;;; Pruning (R-005) ------------------------------------------------------------

(defun mjb-remove-unused-packages ()
  "Delete installed packages that are neither declared nor a dependency.
Wraps built-in `package-autoremove', which reads `package-selected-packages'."
  (interactive)
  (package-autoremove)
  (message "mjb: pruned to %d declared packages + dependencies"
           (length mjb-packages)))

(provide 'mjb-package)
;;; mjb-package.el ends here
