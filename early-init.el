;;; early-init.el --- Early initialization -*- lexical-binding: t -*-

;; Optimize startup by preventing unnecessary work
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

;; Defer file-name-handler-alist for faster startup
(defvar default-file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)
(add-hook 'emacs-startup-hook
          (lambda () (setq file-name-handler-alist default-file-name-handler-alist)))

;; Prevent package.el loading packages prior to init.el
(setq package-enable-at-startup nil)

;; Disable unnecessary UI elements early
(setq inhibit-startup-screen t
      inhibit-startup-message t
      inhibit-startup-echo-area-message t
      initial-scratch-message nil)

;; Disable UI elements before they're loaded
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(push '(horizontal-scroll-bars) default-frame-alist)

;; Set frame size and position
(push '(width . 120) default-frame-alist)
(push '(height . 40) default-frame-alist)

;; Prevent unwanted runtime compilation for native-comp
(setq native-comp-deferred-compilation nil
      native-comp-async-report-warnings-errors 'silent)

;; Prevent frame resizing on font change
(setq frame-inhibit-implied-resize t)

;; Faster rendering
(setq-default bidi-display-reordering 'left-to-right
              bidi-paragraph-direction 'left-to-right)
(setq bidi-inhibit-bpa t)

;; Reduce rendering workload
(setq fast-but-imprecise-scrolling t
      redisplay-skip-fontification-on-input t)

(provide 'early-init)
;;; early-init.el ends here