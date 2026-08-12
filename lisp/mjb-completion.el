;;; mjb-completion.el --- Minibuffer and in-buffer completion -*- lexical-binding: t -*-

;;; Commentary:
;; The one place this configuration deliberately uses packages rather than
;; hand-written elisp, and it is worth saying why.
;;
;; vertico (1708 lines), corfu (1989), cape (1577) are smaller than `hydra'
;; and do far more.  Their design is to implement *nothing*: they wire together
;; Emacs's existing `completing-read' and `completion-at-point' APIs and supply
;; a UI.  Built-in `fido-vertical-mode' would save those lines at a real loss of
;; capability -- on the "remove bloat" test these packages pass.
;;
;; consult (5781) is the one genuine judgement call: `occur', `grep' and
;; `switch-to-buffer' cover the same ground without live preview.  Kept, because
;; searching across book chapters is a daily operation here.
;;
;; Requirement refs: R-008 (justified packages), R-032/F-04 (cape off C-c p).

;;; Code:

(require 'mjb-core)

(defgroup mjb-completion nil "Completion." :group 'completion)

;;;; Minibuffer UI --------------------------------------------------------------

(require 'vertico)
(setq vertico-cycle t
      vertico-resize nil
      vertico-count 12)
(vertico-mode 1)

;; Show the full path progressively when completing file names, and let RET on
;; a directory descend rather than exit.
(require 'vertico-directory nil t)
(when (fboundp 'vertico-directory-tidy)
  (add-hook 'rfn-eshadow-update-overlay-hook #'vertico-directory-tidy))

;;;; Matching -------------------------------------------------------------------
;; `orderless' lets you type space-separated fragments in any order, which is
;; what makes long LaTeX label and file names findable.

(require 'orderless)
(setq completion-styles '(orderless basic)
      completion-category-defaults nil
      completion-category-overrides '((file (styles basic partial-completion))
                                      (eglot (styles orderless))
                                      (eglot-capf (styles orderless)))
      ;; Case-insensitive completion everywhere.
      completion-ignore-case t
      read-buffer-completion-ignore-case t
      read-file-name-completion-ignore-case t)

;;;; Annotations ----------------------------------------------------------------

(require 'marginalia)
(marginalia-mode 1)

;;;; Search and navigation commands ---------------------------------------------

(require 'consult)
(require 'xref)
(setq ;; Use ripgrep (installed at ~/.cargo/bin/rg).
      consult-narrow-key "<"
      consult-line-start-from-top nil
      ;; Preview only the head of a large file -- book PDFs, .bbl and build
      ;; logs live next to the sources here.  (Named `consult-preview-max-size'
      ;; in consult 1.x; this is the consult 3.x spelling.)
      consult-preview-partial-size (* 1024 1024)
      consult-preview-max-count 10
      ;; `register-preview' and xref integration, per consult's own advice.
      register-preview-delay 0.5
      xref-show-xrefs-function #'consult-xref
      xref-show-definitions-function #'consult-xref)

;; Preview on an explicit key rather than on every candidate motion: previewing
;; each line of a 3000-line main.tex as you move is measurable work.
(consult-customize
 consult-line consult-ripgrep consult-grep consult-buffer
 :preview-key '(:debounce 0.3 any))

;;;; In-buffer completion -------------------------------------------------------

(require 'corfu)
;; In corfu 2.x the auto-completion timing knobs live in a separate library
;; that corfu loads on demand; requiring it here so the settings below apply.
(require 'corfu-auto nil t)

;; Upstream defaults `corfu-auto' to nil and says why: some
;; completion-at-point functions execute arbitrary code, notably
;; `elisp-completion-at-point'.  Auto-completion in an untrusted file is
;; therefore a code-execution path.  Enabled here to match your previous
;; behaviour, but see `mjb-completion-auto-safe-modes' below for the scoping.
(setq corfu-auto t
      corfu-auto-delay 0.2
      corfu-auto-prefix 2
      corfu-cycle t
      corfu-quit-no-match 'separator
      corfu-quit-at-boundary 'separator
      corfu-preselect 'prompt
      corfu-scroll-margin 3
      ;; Do not insert the preview into the buffer; it confuses `undo' and, in
      ;; prose, silently mangles words as you type.
      corfu-preview-current nil)
(global-corfu-mode 1)

;; Documentation popup beside the candidate list.
(require 'corfu-popupinfo nil t)
(when (fboundp 'corfu-popupinfo-mode)
  (setq corfu-popupinfo-delay '(0.5 . 0.2)
        corfu-popupinfo-max-height 12)
  (add-hook 'corfu-mode-hook #'corfu-popupinfo-mode))

;; Persist the ordering of candidates you actually pick.
(require 'corfu-history nil t)
(when (fboundp 'corfu-history-mode)
  (corfu-history-mode 1)
  (add-to-list 'savehist-additional-variables 'corfu-history))

;;;; Terminal behaviour ---------------------------------------------------------
;; Corfu draws in a child frame, which does not exist on a tty before Emacs 31
;; (it checks `tty-child-frames'; we are on 30.2, so `corfu--popup-support-p'
;; returns nil in every terminal frame -- verified).
;;
;; The good news, also verified: corfu does not break in that case.  Its
;; `corfu--in-region' delegates to the default `completion-in-region-function'
;; when the popup is unsupported, so the terminal simply gets Emacs's built-in
;; *Completions* UI -- which Emacs 30 improved considerably.  One configuration
;; is therefore correct in both frame types and the `corfu-terminal' package is
;; not needed.  (If you later want the popup on a tty, that package is the
;; one-line addition; Emacs 31 will make it unnecessary.)

;; Make the built-in fallback pleasant, since it is what the terminal uses.
(setq completion-auto-help 'lazy
      completion-auto-select 'second-tab
      completions-max-height 12
      completions-format 'one-column
      completions-detailed t
      completions-sort 'historical)

;; Auto-completion only where there is a popup to show.  Without this the
;; auto-trigger would pop the *Completions* window open while you type.
;; Decided per frame at startup rather than at load time, because when Emacs
;; runs as a daemon no frame exists yet while this file is being read.
(defun mjb-completion-tune-for-frame ()
  "Enable `corfu-auto' only when the current frame can show the popup."
  (setq corfu-auto (display-graphic-p)))
(add-hook 'emacs-startup-hook #'mjb-completion-tune-for-frame)
(add-hook 'server-after-make-frame-hook #'mjb-completion-tune-for-frame)

;;;; Completion-at-point backends (F-04) ----------------------------------------
;; The previous config bound nine cape backends to `C-c p <x>', all of which
;; were dead: `C-c p' is the project prefix keymap and shadowed every one of
;; them.  Binding backends to keys was never the intended usage anyway -- they
;; belong in `completion-at-point-functions', where normal completion reaches
;; them.

(require 'cape)
(add-hook 'completion-at-point-functions #'cape-file 90)
(add-hook 'completion-at-point-functions #'cape-dabbrev 91)

(add-hook 'emacs-lisp-mode-hook
          (lambda () (add-hook 'completion-at-point-functions
                               #'cape-elisp-symbol -10 t)))

;; In prose, complete from the dictionary and from words already in the buffer
;; rather than from code symbols.
(dolist (hook '(text-mode-hook markdown-mode-hook))
  (add-hook hook (lambda ()
                   (add-hook 'completion-at-point-functions #'cape-dict 92 t))))

;; cape 2.x replaced `cape-dabbrev-min-length' and
;; `cape-dabbrev-check-other-buffers' with a single buffer-selection function.
(setq cape-dabbrev-buffer-function #'cape-same-mode-buffers
      ;; Verified present: /usr/share/dict/words -> /etc/dictionaries-common/words
      cape-dict-file "/usr/share/dict/words")

;;;; Auto-completion safety (goal 2) --------------------------------------------
;; `elisp-completion-at-point' can evaluate code to produce candidates, so
;; automatic completion in a file you did not write is an execution path.
;; Emacs 30 tracks this with `trusted-content'; scope auto-completion to modes
;; where the capf is inert.

(defcustom mjb-completion-auto-unsafe-modes '(emacs-lisp-mode lisp-interaction-mode)
  "Modes where automatic completion is disabled.
Their completion-at-point functions can execute buffer code to compute
candidates.  Manual completion (\\[completion-at-point]) still works."
  :type '(repeat symbol) :group 'mjb-completion)

(defun mjb-completion-disable-auto ()
  "Turn off automatic completion in the current buffer."
  (setq-local corfu-auto nil))

(dolist (mode mjb-completion-auto-unsafe-modes)
  (add-hook (intern (format "%s-hook" mode)) #'mjb-completion-disable-auto))

;;;; Minibuffer behaviour -------------------------------------------------------

;; Do not let TAB in the minibuffer complete to the first match silently.
(setq tab-always-indent 'complete
      completion-cycle-threshold nil)

;; Hide commands in M-x that are not applicable to the current mode.
(setq read-extended-command-predicate #'command-completion-default-include-p)

(provide 'mjb-completion)
;;; mjb-completion.el ends here
