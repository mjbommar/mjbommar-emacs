;;; mjb-project.el --- Projects, search, file sidebar -*- lexical-binding: t -*-

;;; Commentary:
;; Built-in `project.el' is the sole owner of the C-c p prefix, which fixes
;; F-04: the previous config gave that prefix to project.el via `:bind-keymap'
;; AND bound nine cape commands underneath it, so all nine were shadowed and
;; dead while still being documented in KEYBOARD.md.
;;
;; `projectile' (5315 lines) is removed -- it was only present because
;; treemacs-projectile and a centaur-tabs grouping call dragged it in, and its
;; state directory was empty.
;;
;; The file sidebar is ~20 lines of `dired' in a side window, replacing
;; treemacs (12,911 lines) plus treemacs-projectile.
;;
;; Requirement refs: R-032 (single owner of C-c p), R-044 (sidebar on demand).

;;; Code:

(require 'mjb-core)
(require 'project)

;; Declarations for libraries loaded on demand (grep, dired, xref).  `defvar'
;; with no value marks the symbol special for the compiler without loading
;; anything; the settings themselves are inside `with-eval-after-load'.
(defvar xref-search-program)
(defvar grep-command)
(defvar grep-find-ignored-directories)
(defvar grep-find-ignored-files)
(defvar dired-listing-switches)
(defvar dired-dwim-target)
(defvar dired-kill-when-opening-new-dired-buffer)
(defvar dired-recursive-copies)
(defvar dired-recursive-deletes)
(defvar dired-deletion-confirmer)
(defvar dired-auto-revert-buffer)
(defvar-local mjb--sidebar-p nil "Non-nil in the sidebar dired buffer.")
(declare-function dired-noselect "dired")
(declare-function dired-hide-details-mode "dired" (&optional arg))

;;;; Project detection ----------------------------------------------------------

(setq project-vc-extra-root-markers
      ;; Directories that are projects without being a git repository.
      ;;
      ;; Deliberately NOT here: "main.tex" and "Makefile".  Both seemed like
      ;; good ideas and both are wrong -- verified.  Your book repos keep the
      ;; sources in a subdirectory (<redacted-paper>/paper/,
      ;; <redacted-book>/latex/) which also carries a Makefile, so
      ;; those markers made the SUBDIRECTORY the project root: searching a
      ;; chapter could not see docs/, and tab-bar would have labelled the tabs
      ;; "paper" and "latex" instead of the book names.  The git repository
      ;; root is what "project" should mean here.
      ;;
      ;; "pyproject.toml" went the same way: <redacted-book>
      ;; has one in book/, which made book/ the root rather than the repo.
      ;;
      ;; The rule is therefore: the project is the git repository. Drop a
      ;; `.project' file somewhere to override that deliberately.
      '(".project")
      ;; Do not treat every parent directory as a project candidate.
      project-vc-merge-submodules nil)

;; What `project-switch-project' offers.  Trimmed to what actually gets used.
(setq project-switch-commands
      '((project-find-file "Find file" ?f)
        (project-find-regexp "Search" ?s)
        (project-dired "Dired" ?d)
        (magit-project-status "Magit" ?g)
        (project-eshell "Eshell" ?e)))

;;;; Search ---------------------------------------------------------------------
;; ripgrep is installed at ~/.cargo/bin/rg.  `fd' is NOT installed, so
;; `consult-find' falls back to find(1) -- noted rather than silently assumed.

(setq xref-search-program (if (executable-find "rg") 'ripgrep 'grep))

;; These must be set AFTER grep loads: they append to grep's own defaults, and
;; reading `grep-find-ignored-directories' before grep.el is loaded is a
;; void-variable error, not merely a compiler warning.
(with-eval-after-load 'grep
  (setq grep-command "rg --no-heading --line-number --color=never "
        ;; Do not descend into build output when searching a book project.
        grep-find-ignored-directories
        (append '("build" "generated" "_minted*" "arxiv" "submission" "vendor"
                  ".venv" "__pycache__" "node_modules" "elpa" "eln-cache")
                grep-find-ignored-directories)
        grep-find-ignored-files
        (append '("*.pdf" "*.aux" "*.bbl" "*.blg" "*.log" "*.out" "*.synctex.gz"
                  "*.fls" "*.fdb_latexmk" "*.toc" "*.lof" "*.lot")
                grep-find-ignored-files)))

;;;; File sidebar ---------------------------------------------------------------
;; Replaces treemacs.  `dired' already knows how to render a directory tree and
;; navigate it; all that was missing is a window that behaves like a sidebar.

(defcustom mjb-sidebar-width 32
  "Width in columns of the file sidebar." :type 'integer :group 'mjb-ui)

(defvar mjb--sidebar-buffer nil
  "The dired buffer currently acting as the sidebar.")

(defun mjb-sidebar-toggle ()
  "Show or hide a dired sidebar rooted at the current project.
Falls back to `default-directory' when the buffer is not in a project."
  (interactive)
  (if-let ((win (and mjb--sidebar-buffer
                     (get-buffer-window mjb--sidebar-buffer))))
      (delete-window win)
    (let* ((root (or (when-let ((proj (project-current nil)))
                       (project-root proj))
                     default-directory))
           (buf (dired-noselect root)))
      (setq mjb--sidebar-buffer buf)
      (with-current-buffer buf
        (setq-local mjb--sidebar-p t)
        ;; A sidebar should not show line numbers or wrap.
        (display-line-numbers-mode -1)
        (setq-local truncate-lines t)
        (dired-hide-details-mode 1))
      (select-window
       (display-buffer-in-side-window
        buf `((side . left)
              (slot . 0)
              (window-width . ,mjb-sidebar-width)
              (preserve-size . (t . nil))
              (window-parameters . ((no-delete-other-windows . t)
                                    (no-other-window . nil)))))))))

;;;; Dired ----------------------------------------------------------------------

(with-eval-after-load 'dired
  (setq dired-listing-switches "-alh --group-directories-first"
        ;; Copy/move to the directory shown in the other window.
        dired-dwim-target t
        ;; Do not accumulate a dired buffer per directory visited.
        dired-kill-when-opening-new-dired-buffer t
        dired-recursive-copies 'always
        dired-recursive-deletes 'top
        ;; Confirm before deleting; the default asks per file which is worse.
        dired-deletion-confirmer #'y-or-n-p
        ;; Auto-revert dired buffers so the sidebar reflects the filesystem.
        dired-auto-revert-buffer t)
  (require 'dired-x nil t))

(provide 'mjb-project)
;;; mjb-project.el ends here
