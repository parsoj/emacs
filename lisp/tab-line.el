;;; tab-line.el --- window-local tabs with window buffers -*- lexical-binding: t; -*-

;; Copyright (C) 2019 Free Software Foundation, Inc.

;; Author: Juri Linkov <juri@linkov.net>
;; Keywords: windows tabs
;; Maintainer: emacs-devel@gnu.org

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; To enable this mode, run `M-x global-tab-line-mode'.

;;; Code:

(require 'seq) ; tab-line.el is not pre-loaded so it's safe to use it here


(defgroup tab-line nil
  "Window-local tabs."
  :group 'convenience
  :version "27.1")

(defgroup tab-line-faces nil
  "Faces used in the tab line."
  :group 'tab-line
  :group 'faces
  :version "27.1")

(defface tab-line
  '((((type x w32 ns) (class color))
     :inherit variable-pitch
     :height 0.9
     :background "grey85"
     :foreground "black")
    (((type x) (class mono))
     :background "grey")
    (t
     :inverse-video t))
  "Tab line face."
  :version "27.1"
  :group 'tab-line-faces)

(defface tab-line-tab
  '((default
      :inherit tab-line)
    (((class color) (min-colors 88))
     :box (:line-width 1 :style released-button))
    (t
     :inverse-video nil))
  "Tab line face for selected tab."
  :version "27.1"
  :group 'tab-line-faces)

(defface tab-line-tab-inactive
  '((default
      :inherit tab-line-tab)
    (((class color) (min-colors 88))
     :background "grey75")
    (t
     :inverse-video t))
  "Tab line face for non-selected tab."
  :version "27.1"
  :group 'tab-line-faces)

(defface tab-line-highlight
  '((default :inherit tab-line-tab))
  "Tab line face for highlighting."
  :version "27.1"
  :group 'tab-line-faces)

(defface tab-line-close-highlight
  '((t :foreground "red"))
  "Tab line face for highlighting of the close button."
  :version "27.1"
  :group 'tab-line-faces)


(defvar tab-line-tab-map
  (let ((map (make-sparse-keymap)))
    (define-key map [tab-line mouse-1] 'tab-line-select-tab)
    (define-key map [tab-line mouse-2] 'tab-line-close-tab)
    (define-key map "\C-m" 'tab-line-select-tab)
    map)
  "Local keymap for `tab-line-mode' window tabs.")

(defvar tab-line-add-map
  (let ((map (make-sparse-keymap)))
    (define-key map [tab-line mouse-1] 'tab-line-new-tab)
    (define-key map [tab-line mouse-2] 'tab-line-new-tab)
    (define-key map "\C-m" 'tab-line-new-tab)
    map)
  "Local keymap to add `tab-line-mode' window tabs.")

(defvar tab-line-tab-close-map
  (let ((map (make-sparse-keymap)))
    (define-key map [tab-line mouse-1] 'tab-line-close-tab)
    (define-key map [tab-line mouse-2] 'tab-line-close-tab)
    map)
  "Local keymap to close `tab-line-mode' window tabs.")

(defvar tab-line-left-map
  (let ((map (make-sparse-keymap)))
    (define-key map [tab-line mouse-1] 'tab-line-hscroll-left)
    (define-key map [tab-line mouse-2] 'tab-line-hscroll-left)
    (define-key map "\C-m" 'tab-line-new-tab)
    map)
  "Local keymap to scroll `tab-line-mode' window tabs to the left.")

(defvar tab-line-right-map
  (let ((map (make-sparse-keymap)))
    (define-key map [tab-line mouse-1] 'tab-line-hscroll-right)
    (define-key map [tab-line mouse-2] 'tab-line-hscroll-right)
    (define-key map "\C-m" 'tab-line-new-tab)
    map)
  "Local keymap to scroll `tab-line-mode' window tabs to the right.")


(defcustom tab-line-new-tab-choice t
  "Defines what to show in a new tab.
If t, display a selection menu with all available buffers.
If the value is a function, call it with no arguments.
If nil, don't show the new tab button."
  :type '(choice (const     :tag "Buffer menu" t)
                 (function  :tag "Function")
                 (const     :tag "No button" nil))
  :group 'tab-line
  :version "27.1")

(defvar tab-line-new-button
  (propertize " + "
              'display `(image :type xpm
                               :file "tabs/new.xpm"
                               :margin (2 . 0)
                               :ascent center)
              'keymap tab-line-add-map
              'mouse-face 'tab-line-highlight
              'help-echo "Click to add tab")
  "Button for creating a new tab.")

(defcustom tab-line-close-button-show t
  "Defines where to show the close tab button.
If t, show the close tab button on all tabs.
If `selected', show it only on the selected tab.
If `non-selected', show it only on non-selected tab.
If nil, don't show it at all."
  :type '(choice (const :tag "On all tabs" t)
                 (const :tag "On selected tab" selected)
                 (const :tag "On non-selected tabs" non-selected)
                 (const :tag "None" nil))
  :initialize 'custom-initialize-default
  :set (lambda (sym val)
         (set-default sym val)
         (force-mode-line-update))
  :group 'tab-line
  :version "27.1")

(defvar tab-line-close-button
  (propertize " x"
              'display `(image :type xpm
                               :file "tabs/close.xpm"
                               :margin (2 . 0)
                               :ascent center)
              'keymap tab-line-tab-close-map
              'mouse-face 'tab-line-close-highlight
              'help-echo "Click to close tab")
  "Button for closing the clicked tab.")

(defvar tab-line-left-button
  (propertize " <"
              'display `(image :type xpm
                               :file "tabs/left-arrow.xpm"
                               :margin (2 . 0)
                               :ascent center)
              'keymap tab-line-left-map
              'mouse-face 'tab-line-highlight
              'help-echo "Click to scroll left")
  "Button for scrolling horizontally to the left.")

(defvar tab-line-right-button
  (propertize "> "
              'display `(image :type xpm
                               :file "tabs/right-arrow.xpm"
                               :margin (2 . 0)
                               :ascent center)
              'keymap tab-line-right-map
              'mouse-face 'tab-line-highlight
              'help-echo "Click to scroll right")
  "Button for scrolling horizontally to the right.")

(defvar tab-line-separator nil)

(defvar tab-line-tab-name-ellipsis
  (if (char-displayable-p ?…) "…" "..."))


(defcustom tab-line-tab-name-function #'tab-line-tab-name-buffer
  "Function to get a tab name.
Function gets two arguments: tab to get name for and a list of tabs
to display.  By default, use function `tab-line-tab-name'."
  :type '(choice (const :tag "Buffer name"
                        tab-line-tab-name-buffer)
                 (const :tag "Truncated buffer name"
                        tab-line-tab-name-truncated-buffer)
                 (function  :tag "Function"))
  :initialize 'custom-initialize-default
  :set (lambda (sym val)
         (set-default sym val)
         (force-mode-line-update))
  :group 'tab-line
  :version "27.1")

(defun tab-line-tab-name-buffer (buffer &optional _buffers)
  "Generate tab name from BUFFER.
Reduce tab width proportionally to space taken by other tabs.
This function can be overridden by changing the default value of the
variable `tab-line-tab-name-function'."
  (buffer-name buffer))

(defun tab-line-tab-name-truncated-buffer (buffer &optional buffers)
  "Generate tab name from BUFFER.
Reduce tab width proportionally to space taken by other tabs."
  (let ((tab-name (buffer-name buffer))
        (limit (when buffers
                 (max 1 (- (/ (window-width) (length buffers)) 3)))))
    (if (or (not limit) (< (length tab-name) limit))
        tab-name
      (propertize (truncate-string-to-width tab-name limit nil nil
                                            tab-line-tab-name-ellipsis)
                  'help-echo tab-name))))

(defvar tab-line-tabs-limit nil
  "Maximum number of buffer tabs displayed in the tab line.
If nil, no limit.")

(defcustom tab-line-tabs-function #'tab-line-tabs-window-buffers
  "Function to get a list of tabs to display in the tab line.
This function should return either a list of buffers whose names will
be displayed, or just a list of strings to display in the tab line.
By default, use function `tab-line-tabs-window-buffers' that
returns a list of buffers associated with the selected window.
When `tab-line-tabs-mode-buffers', return a list of buffers
with the same major mode as the current buffer."
  :type '(choice (const :tag "Window buffers"
                        tab-line-tabs-window-buffers)
                 (const :tag "Same mode buffers"
                        tab-line-tabs-mode-buffers)
                 (function :tag "Function"))
  :initialize 'custom-initialize-default
  :set (lambda (sym val)
         (set-default sym val)
         (force-mode-line-update))
  :group 'tab-line
  :version "27.1")

(defun tab-line-tabs-mode-buffers ()
  "Return a list of buffers with the same major mode with current buffer."
  (let* ((window (selected-window))
         (buffer (window-buffer window))
         (mode (with-current-buffer buffer major-mode)))
    (seq-sort-by #'buffer-name #'string<
                 (seq-filter (lambda (b) (with-current-buffer b
                                           (derived-mode-p mode)))
                             (buffer-list)))))

(defun tab-line-tabs-window-buffers ()
  "Return a list of tabs that should be displayed in the tab line.
By default returns a list of window buffers, i.e. buffers previously
shown in the same window where the tab line is displayed.
This list can be overridden by changing the default value of the
variable `tab-line-tabs-function'."
  (let* ((window (selected-window))
         (buffer (window-buffer window))
         (next-buffers (seq-remove (lambda (b) (eq b buffer))
                                   (window-next-buffers window)))
         (next-buffers (seq-filter #'buffer-live-p next-buffers))
         (prev-buffers (seq-remove (lambda (b) (eq b buffer))
                                   (mapcar #'car (window-prev-buffers window))))
         (prev-buffers (seq-filter #'buffer-live-p prev-buffers))
         ;; Remove next-buffers from prev-buffers
         (prev-buffers (seq-difference prev-buffers next-buffers)))
    (if (natnump tab-line-tabs-limit)
        (let* ((half-limit (/ tab-line-tabs-limit 2))
               (prev-buffers-limit
                (if (> (length prev-buffers) half-limit)
                    (if (> (length next-buffers) half-limit)
                        half-limit
                      (+ half-limit (- half-limit (length next-buffers))))
                  (length prev-buffers)))
               (next-buffers-limit
                (- tab-line-tabs-limit prev-buffers-limit)))
          (append (reverse (seq-take prev-buffers prev-buffers-limit))
                  (list buffer)
                  (seq-take next-buffers next-buffers-limit)))
      (append (reverse prev-buffers)
              (list buffer)
              next-buffers))))

(defun tab-line-format ()
  "Template for displaying tab line for selected window."
  (let* ((window (selected-window))
         (selected-buffer (window-buffer window))
         (tabs (funcall tab-line-tabs-function))
         (separator (or tab-line-separator (if window-system " " "|")))
         (hscroll (window-parameter nil 'tab-line-hscroll))
         (strings
          (mapcar
           (lambda (tab)
             (concat
              separator
              (apply 'propertize
                     (concat (propertize
                              (funcall tab-line-tab-name-function tab tabs)
                              'keymap tab-line-tab-map)
                             (or (and tab-line-close-button-show
                                      (not (eq tab-line-close-button-show
                                               (if (eq tab selected-buffer)
                                                   'non-selected
                                                 'selected)))
                                      tab-line-close-button) ""))
                     `(
                       tab ,tab
                       face ,(if (eq tab selected-buffer)
                                 'tab-line-tab
                               'tab-line-tab-inactive)
                       mouse-face tab-line-highlight))))
           tabs)))
    (append
     (list separator
           (when (and (natnump hscroll) (> hscroll 0))
             tab-line-left-button)
           (when (if (natnump hscroll)
                     (< hscroll (1- (length strings)))
                   (> (length strings) 1))
               tab-line-right-button))
     (if hscroll (nthcdr hscroll strings) strings)
     (list (concat separator (when tab-line-new-tab-choice
                               tab-line-new-button))))))


(defun tab-line-hscroll (&optional arg window)
  (let* ((hscroll (window-parameter window 'tab-line-hscroll))
         (tabs (if window
                   (with-selected-window window (funcall tab-line-tabs-function))
                 (funcall tab-line-tabs-function))))
    (set-window-parameter
     window 'tab-line-hscroll
     (max 0 (min (+ (or hscroll 0) (or arg 1))
                 (1- (length tabs)))))
    (when window
      (force-mode-line-update t))))

(defun tab-line-hscroll-right (&optional arg mouse-event)
  (interactive (list current-prefix-arg last-nonmenu-event))
  (let ((window (and (listp mouse-event) (posn-window (event-start mouse-event)))))
    (tab-line-hscroll arg window)
    (force-mode-line-update window)))

(defun tab-line-hscroll-left (&optional arg mouse-event)
  (interactive (list current-prefix-arg last-nonmenu-event))
  (let ((window (and (listp mouse-event) (posn-window (event-start mouse-event)))))
    (tab-line-hscroll (- (or arg 1)) window)
    (force-mode-line-update window)))


(defun tab-line-new-tab (&optional mouse-event)
  "Add a new tab to the tab line.
Usually is invoked by clicking on the plus-shaped button.
But any switching to other buffer also adds a new tab
corresponding to the switched buffer."
  (interactive (list last-nonmenu-event))
  (if (functionp tab-line-new-tab-choice)
      (funcall tab-line-new-tab-choice)
    (if (and (listp mouse-event) window-system) ; (display-popup-menus-p)
        (mouse-buffer-menu mouse-event) ; like (buffer-menu-open)
      ;; tty menu doesn't support mouse clicks, so use tmm
      (tmm-prompt (mouse-buffer-menu-keymap)))))

(defun tab-line-select-tab (&optional e)
  "Switch to the selected tab.
This command maintains the original order of prev/next buffers.
So for example, switching to a previous tab is equivalent to
using the `previous-buffer' command."
  (interactive "e")
  (let* ((posnp (event-start e))
         (window (posn-window posnp))
         (buffer (get-pos-property 1 'tab (car (posn-string posnp))))
         (window-buffer (window-buffer window))
         (next-buffers (seq-remove (lambda (b) (eq b window-buffer))
                                   (window-next-buffers window)))
         (prev-buffers (seq-remove (lambda (b) (eq b window-buffer))
                                   (mapcar #'car (window-prev-buffers window))))
         ;; Remove next-buffers from prev-buffers
         (prev-buffers (seq-difference prev-buffers next-buffers)))
    (cond
     ((and (eq tab-line-tabs-function #'tab-line-tabs-window-buffers)
           (memq buffer next-buffers))
      (dotimes (_ (1+ (seq-position next-buffers buffer)))
        (switch-to-next-buffer window)))
     ((and (eq tab-line-tabs-function #'tab-line-tabs-window-buffers)
           (memq buffer prev-buffers))
      (dotimes (_ (1+ (seq-position prev-buffers buffer)))
        (switch-to-prev-buffer window)))
     (t
      (with-selected-window window
        (switch-to-buffer buffer))))))

(defun tab-line-switch-to-prev-tab (&optional mouse-event)
  "Switch to the previous tab.
Its effect is the same as using the `previous-buffer' command
(\\[previous-buffer])."
  (interactive (list last-nonmenu-event))
  (let ((window (and (listp mouse-event) (posn-window (event-start mouse-event)))))
    (if (eq tab-line-tabs-function #'tab-line-tabs-window-buffers)
        (switch-to-prev-buffer window)
      (with-selected-window (or window (selected-window))
        (let ((buffer (cadr (memq (current-buffer)
                                  (reverse (funcall tab-line-tabs-function))))))
          (when buffer (switch-to-buffer buffer)))))))

(defun tab-line-switch-to-next-tab (&optional mouse-event)
  "Switch to the next tab.
Its effect is the same as using the `next-buffer' command
(\\[next-buffer])."
  (interactive (list last-nonmenu-event))
  (let ((window (and (listp mouse-event) (posn-window (event-start mouse-event)))))
    (if (eq tab-line-tabs-function #'tab-line-tabs-window-buffers)
        (switch-to-next-buffer window)
      (with-selected-window (or window (selected-window))
        (let ((buffer (cadr (memq (current-buffer)
                                  (funcall tab-line-tabs-function)))))
          (when buffer (switch-to-buffer buffer)))))))


(defcustom tab-line-close-tab-action 'bury-buffer
  "Defines what to do on closing the tab.
If `bury-buffer', put the tab's buffer at the end of the list of all
buffers that effectively hides the buffer's tab from the tab line.
If `kill-buffer', kills the tab's buffer."
  :type '(choice (const :tag "Bury buffer" bury-buffer)
                 (const :tag "Kill buffer" kill-buffer))
  :group 'tab-line
  :version "27.1")

(defun tab-line-close-tab (&optional mouse-event)
  "Close the selected tab.
Usually is invoked by clicking on the close button on the right side
of the tab.  This command buries the buffer, so it goes out of sight
from the tab line."
  (interactive (list last-nonmenu-event))
  (let* ((posnp (and (listp mouse-event) (event-start mouse-event)))
         (window (and posnp (posn-window posnp)))
         (buffer (or (get-pos-property 1 'tab (car (posn-string posnp)))
                     (current-buffer))))
    (with-selected-window (or window (selected-window))
      (cond
       ((eq tab-line-close-tab-action 'kill-buffer)
        (kill-buffer buffer))
       ((eq tab-line-close-tab-action 'bury-buffer)
        (if (eq buffer (current-buffer))
            (bury-buffer)
          (set-window-prev-buffers nil (assq-delete-all buffer (window-prev-buffers)))
          (set-window-next-buffers nil (delq buffer (window-next-buffers))))))
      (force-mode-line-update))))


;;;###autoload
(define-minor-mode tab-line-mode
  "Toggle display of window tab line in the buffer."
  :lighter nil
  (setq tab-line-format (when tab-line-mode '(:eval (tab-line-format)))))

(defcustom tab-line-exclude-modes
  '(completion-list-mode)
  "List of major modes in which the tab line is not enabled."
  :type '(repeat symbol)
  :group 'tab-line
  :version "27.1")

;;;###autoload
(defvar tab-line-exclude nil)
;;;###autoload
(make-variable-buffer-local 'tab-line-exclude)

(defun tab-line-mode--turn-on ()
  "Turn on `tab-line-mode'."
  (unless (or (minibufferp)
              (string-match-p "\\` " (buffer-name))
              (memq major-mode tab-line-exclude-modes)
              (get major-mode 'tab-line-exclude)
              (buffer-local-value 'tab-line-exclude (current-buffer)))
    (tab-line-mode 1)))

;;;###autoload
(define-globalized-minor-mode global-tab-line-mode
  tab-line-mode tab-line-mode--turn-on
  :group 'tab-line
  :version "27.1")


(global-set-key [tab-line mouse-4]    'tab-line-hscroll-left)
(global-set-key [tab-line mouse-5]    'tab-line-hscroll-right)
(global-set-key [tab-line wheel-up]   'tab-line-hscroll-left)
(global-set-key [tab-line wheel-down] 'tab-line-hscroll-right)

(global-set-key [tab-line C-mouse-4]    'tab-line-switch-to-prev-tab)
(global-set-key [tab-line C-mouse-5]    'tab-line-switch-to-next-tab)
(global-set-key [tab-line C-wheel-up]   'tab-line-switch-to-prev-tab)
(global-set-key [tab-line C-wheel-down] 'tab-line-switch-to-next-tab)


(provide 'tab-line)
;;; tab-line.el ends here
