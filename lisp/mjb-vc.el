;;; mjb-vc.el --- Version control -*- lexical-binding: t -*-

;;; Commentary:
;; Magit (25,862 lines) is the one package in this configuration that is large
;; and stays large.  That is essential complexity: git's porcelain genuinely is
;; that complicated, and it is lazily loaded, so it costs 0 ms at startup.
;;
;; diff-hl is the one Tier-B item I flagged as a trap to reimplement -- async
;; VC diff, buffer-change tracking, and margin rendering under narrowing and
;; revert is a lot more than it looks.  Kept as a package, deliberately.
;;
;; The important fix here is `diff-hl-margin-mode': there is no fringe in a
;; terminal, so without it the indicators are invisible in the primary
;; environment.  The previous config enabled diff-hl and never turned this on.
;;
;; Requirement refs: R-056.

;;; Code:

(require 'mjb-core)

;; Magit and diff-hl settings live inside `with-eval-after-load'/after their
;; own require; declare the symbols so the compiler can check this file
;; without magit being loaded at compile time.
(defvar magit-display-buffer-function)
(defvar magit-diff-refine-hunk)
(defvar magit-save-repository-buffers)
(defvar magit-status-goto-file-position)
(defvar magit-section-visibility-indicator)
(defvar diff-hl-flydiff-delay)
(defvar vc-git-diff-switches)
(defvar vc-git-print-log-follow)
(declare-function magit-display-buffer-same-window-except-diff-v1 "magit-mode" (buffer))
(declare-function diff-hl-magit-pre-refresh "diff-hl")
(declare-function diff-hl-magit-post-refresh "diff-hl")

;;;; Magit ----------------------------------------------------------------------

(with-eval-after-load 'magit
  (setq ;; Open magit in the current window rather than splitting; on an
        ;; 80-column terminal a side-by-side status buffer is unusable.
        magit-display-buffer-function
        #'magit-display-buffer-same-window-except-diff-v1
        ;; Show word-level diffs in hunks -- much easier to read for prose,
        ;; which is most of what gets committed here.
        magit-diff-refine-hunk 'all
        ;; Do not ask about saving; mjb-core already auto-saves aggressively.
        magit-save-repository-buffers 'dontask
        ;; A book repo has a lot of generated files; keep the status readable.
        magit-status-goto-file-position t)

  ;; Emacs 30 ships `which-key'; magit's own popup does not need to fight it.
  (setq magit-section-visibility-indicator '("..." . t)))

;; `magit' autoloads `magit-status', so this needs no eager require.
;; The keybinding itself lives in mjb-keys.el.

;;;; Change indicators ----------------------------------------------------------

(require 'diff-hl)

(setq diff-hl-draw-borders nil
      ;; Update as you type rather than only on save -- the whole point is to
      ;; see what you have changed before committing.
      diff-hl-flydiff-delay 0.3)

(defun mjb-vc-setup-indicators (&optional _frame)
  "Enable the display mode diff-hl needs for the current frame type.
Graphical frames have a fringe; terminal frames do not, and without
`diff-hl-margin-mode' the indicators simply do not render there."
  (if (display-graphic-p)
      (when (bound-and-true-p diff-hl-margin-mode)
        (diff-hl-margin-mode -1))
    (diff-hl-margin-mode 1)))

(add-hook 'emacs-startup-hook #'mjb-vc-setup-indicators)
(add-hook 'server-after-make-frame-hook #'mjb-vc-setup-indicators)

(add-hook 'prog-mode-hook #'diff-hl-mode)
(add-hook 'text-mode-hook #'diff-hl-mode)
(add-hook 'conf-mode-hook #'diff-hl-mode)

;; Live diffing while editing, not just on save.
(diff-hl-flydiff-mode 1)

;; Keep the indicators honest when magit stages or commits behind our back.
(with-eval-after-load 'magit
  (add-hook 'magit-pre-refresh-hook #'diff-hl-magit-pre-refresh)
  (add-hook 'magit-post-refresh-hook #'diff-hl-magit-post-refresh))

;;;; Built-in VC ----------------------------------------------------------------
;; Magit is the daily driver, but `vc' still backs the modeline branch segment
;; and `C-x v =' is quicker than opening magit for a single file.

(setq vc-handled-backends '(Git)       ; nothing here is not git
      vc-git-diff-switches '("--histogram")
      vc-git-print-log-follow t
      ;; Do not stat remote files; /nas4 mounts can be slow or absent.
      vc-ignore-dir-regexp
      (format "\\(%s\\)\\|\\(%s\\)"
              locate-dominating-stop-dir-regexp
              "[\\/][\\/][^\\/]+[\\/]"))

(provide 'mjb-vc)
;;; mjb-vc.el ends here
