;;; mjb-latex.el --- LaTeX authoring, no external packages -*- lexical-binding: t -*-

;;; Commentary:
;; The largest requirement (R-050) and the one with no support at all in the
;; previous configuration -- despite .tex being the most-edited file type on
;; this machine.
;;
;; This is built entirely from Emacs built-ins:
;;
;;   tex-mode   latex-mode, font-lock, environment insertion   built-in
;;   reftex     \ref / \cite completion, ToC, label management  built-in
;;   bibtex     bibliography editing                            built-in
;;   compile    async build + error navigation                  built-in
;;   outline    section folding                                 built-in
;;
;; AUCTeX (~50,000 lines) is deliberately NOT used.  RefTeX is standalone --
;; the part of AUCTeX people actually need for book-length work is already in
;; Emacs.  What AUCTeX adds beyond this is preview-latex, a richer math-mode,
;; and its own build abstraction; latexmk already handles the build.
;;
;; Mode-local keys live here (they cannot collide globally); see mjb-keys.el
;; for the global table.

;;; Code:

(require 'tex-mode)
(require 'compile)

;; RefTeX and BibTeX load lazily; declare their variables for the compiler
;; without pulling either into startup.
(defvar reftex-plug-into-AUCTeX)
(defvar reftex-toc-split-windows-horizontally)
(defvar reftex-toc-follow-mode)
(defvar reftex-ref-macro-prompt)
(defvar reftex-save-parse-info)
(defvar reftex-enable-partial-scans)
(defvar reftex-use-multiple-selection-buffers)
(defvar bibtex-align-at-equal-sign)
(defvar bibtex-text-indentation)
(declare-function reftex-mode "reftex")
(declare-function reftex-toc "reftex-toc")

(defgroup mjb-latex nil "LaTeX authoring." :group 'tex)

(defcustom mjb-latex-build-command
  "latexmk -pdf -interaction=nonstopmode -file-line-error -synctex=1"
  "Command used to build a LaTeX document.
`-file-line-error' is load-bearing: it makes pdflatex report errors as
`./file.tex:12: message', which the built-in `gnu' entry in
`compilation-error-regexp-alist' already matches.  Without it, Emacs cannot
jump to errors -- there is no TeX-specific regexp in core."
  :type 'string :group 'mjb-latex)

(defcustom mjb-latex-pdf-viewer
  (seq-find #'executable-find '("xdg-open" "zathura" "evince" "okular"))
  "External program used to open the built PDF.
Terminal Emacs cannot display a PDF; on a GUI build `doc-view-mode' is an
alternative but is slow on book-length documents."
  :type '(choice string (const nil)) :group 'mjb-latex)

;;;; Master-file detection ------------------------------------------------------
;; Every project here is multi-file: editing chapters/01-arpanet.tex must build
;; latex/main.tex, not the chapter.  RefTeX already understands `tex-main-file',
;; so setting it buffer-locally configures the build AND the reference machinery
;; in one move.

(defun mjb-latex--has-documentclass-p (file)
  "Return non-nil if FILE contains a \\documentclass declaration."
  (and (file-readable-p file)
       (with-temp-buffer
         ;; 4 KB is plenty -- \documentclass is in the preamble by definition.
         (insert-file-contents file nil 0 4096)
         (goto-char (point-min))
         (re-search-forward "^[ \t]*\\\\documentclass" nil t))))

(defun mjb-latex-find-master (&optional file)
  "Return the master .tex file governing FILE (default: current buffer).
Searches, in order: FILE itself, then `main.tex'/`master.tex' and any other
.tex file carrying \\documentclass, walking up to four directories upward.
Returns nil if nothing looks like a master."
  (let* ((file (or file buffer-file-name))
         (dir (and file (file-name-directory file))))
    (when file
      (or (and (mjb-latex--has-documentclass-p file) file)
          (catch 'found
            (dotimes (_ 4)
              (when dir
                ;; Conventional names first, then anything with a documentclass.
                (dolist (cand (append
                               (mapcar (lambda (n) (expand-file-name n dir))
                                       '("main.tex" "master.tex" "thesis.tex"
                                         "paper.tex" "book.tex"))
                               (ignore-errors
                                 (directory-files dir t "\\.tex\\'" t))))
                  (when (mjb-latex--has-documentclass-p cand)
                    (throw 'found cand)))
                (setq dir (file-name-directory (directory-file-name dir)))))
            nil)))))

(defun mjb-latex-set-master ()
  "Set `tex-main-file' for this buffer, which also configures RefTeX."
  (when-let ((master (mjb-latex-find-master)))
    (setq-local tex-main-file master)))

;;;; Build ---------------------------------------------------------------------

(defun mjb-latex-build (&optional arg)
  "Build the master document with `mjb-latex-build-command'.
Runs asynchronously via `compile', so Emacs stays responsive (R-050c).
With prefix ARG, edit the command before running it."
  (interactive "P")
  (let* ((master (or (mjb-latex-find-master)
                     (user-error "mjb-latex: no master .tex found for this buffer")))
         (default-directory (file-name-directory master))
         (cmd (format "%s %s" mjb-latex-build-command
                      (shell-quote-argument (file-name-nondirectory master)))))
    (save-some-buffers t)
    (compile (if arg (read-shell-command "Build: " cmd) cmd))))

(defun mjb-latex-clean ()
  "Remove latexmk's auxiliary files for the master document."
  (interactive)
  (let* ((master (or (mjb-latex-find-master) (user-error "No master")))
         (default-directory (file-name-directory master)))
    (compile (format "latexmk -c %s"
                     (shell-quote-argument (file-name-nondirectory master))))))

(defun mjb-latex-view ()
  "Open the PDF built from the master document."
  (interactive)
  (let* ((master (or (mjb-latex-find-master) (user-error "No master")))
         (pdf (concat (file-name-sans-extension master) ".pdf")))
    (unless (file-exists-p pdf)
      (user-error "mjb-latex: %s does not exist -- build first" pdf))
    (cond
     ((display-graphic-p) (find-file pdf))   ; doc-view on a GUI build
     (mjb-latex-pdf-viewer
      (call-process mjb-latex-pdf-viewer nil 0 nil pdf)
      (message "mjb-latex: opened %s" (file-name-nondirectory pdf)))
     (t (user-error "mjb-latex: no PDF viewer found")))))

;;;; Structure navigation -------------------------------------------------------
;; `tex-mode' gives imenu sectioning for the current file; `reftex-toc' gives a
;; navigable table of contents across every \input'd file, which is what you
;; actually want in a book.

(defun mjb-latex-outline-level ()
  "Return the outline depth of the sectioning command at point."
  (let ((head (match-string 1)))
    (or (cdr (assoc head '(("part" . 1) ("chapter" . 2) ("section" . 3)
                           ("subsection" . 4) ("subsubsection" . 5)
                           ("paragraph" . 6))))
        7)))

;;;; Mode setup -----------------------------------------------------------------

(defun mjb-latex-mode-setup ()
  "Configure a LaTeX buffer.  Added to `tex-mode-hook' and `latex-mode-hook'."
  (mjb-latex-set-master)

  ;; Prose settings.  R-021: visual-line-mode is the only command in your
  ;; entire M-x history, run twice -- it should never need typing again.
  (visual-line-mode 1)
  (setq-local truncate-lines nil)
  ;; No line numbers in prose (R-022).
  (display-line-numbers-mode -1)

  ;; RefTeX: labels, references, citations, cross-file ToC.  Built in, and
  ;; standalone -- `reftex-plug-into-AUCTeX' stays nil because there is no
  ;; AUCTeX to plug into.
  (when (require 'reftex nil t)
    (setq reftex-plug-into-AUCTeX nil)
    (reftex-mode 1))

  ;; Section folding via built-in outline.
  (setq-local outline-regexp
              "\\\\\\(part\\|chapter\\|section\\|subsection\\|subsubsection\\|paragraph\\)\\*?{")
  (setq-local outline-level #'mjb-latex-outline-level)
  (outline-minor-mode 1)

  ;; Build with the mode's conventional key.  These are mode-local, so they
  ;; cannot collide with the global table, and C-c C-<letter> is the range
  ;; Emacs reserves for modes.
  (local-set-key (kbd "C-c C-c") #'mjb-latex-build)
  (local-set-key (kbd "C-c C-v") #'mjb-latex-view)
  (local-set-key (kbd "C-c C-k") #'mjb-latex-clean)
  (local-set-key (kbd "C-c C-t") #'reftex-toc))

(add-hook 'tex-mode-hook   #'mjb-latex-mode-setup)
(add-hook 'latex-mode-hook #'mjb-latex-mode-setup)

;; RefTeX settings that only matter once it loads.
(with-eval-after-load 'reftex
  (setq reftex-toc-split-windows-horizontally nil
        reftex-toc-follow-mode t
        ;; Ask which macro to use rather than defaulting to \ref.
        reftex-ref-macro-prompt t
        reftex-save-parse-info t
        reftex-enable-partial-scans t
        reftex-use-multiple-selection-buffers t))

;; BibTeX: align fields the way most journals expect.
(with-eval-after-load 'bibtex
  (setq bibtex-align-at-equal-sign t
        bibtex-text-indentation 20))

(provide 'mjb-latex)
;;; mjb-latex.el ends here
