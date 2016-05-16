;;; funcs.el --- Helm Layer functions File for Spacemacs
;;
;; Copyright (c) 2012-2016 Sylvain Benner & Contributors
;;
;; Author: Sylvain Benner <sylvain.benner@gmail.com>
;; URL: https://github.com/syl20bnr/spacemacs
;;
;; This file is not part of GNU Emacs.
;;
;;; License: GPLv3



(defun spacemacs//helm-cleanup ()
  "Cleanup some helm related states when quitting."
  ;; deactivate any running transient map (transient-state)
  (setq overriding-terminal-local-map nil))


;; REPLs integration

(defun helm-available-repls ()
  "Show all the repls available."
  (interactive)
  (let ((helm-available-repls
         `((name . "HELM available REPLs")
           (candidates . ,(mapcar #'car spacemacs-repl-list))
           (action . (lambda (candidate)
                       (let ((repl (cdr (assoc candidate spacemacs-repl-list))))
                         (require (car repl))
                         (call-interactively (cdr repl))))))))
    (helm :sources '(helm-available-repls)
          :buffer "*helm repls*")))


;; Search tools integration

(defun spacemacs//helm-do-grep-region-or-symbol
          (&optional targs use-region-or-symbol-p)
        "Version of `helm-do-grep' with a default input."
        (interactive)
        (require 'helm)
        (cl-letf*
            (((symbol-function 'this-fn) (symbol-function 'helm-do-grep-1))
             ((symbol-function 'helm-do-grep-1)
              (lambda (targets &optional recurse zgrep exts
                               default-input region-or-symbol-p)
                (let* ((new-input (when region-or-symbol-p
                                    (if (region-active-p)
                                        (buffer-substring-no-properties
                                         (region-beginning) (region-end))
                                      (thing-at-point 'symbol t))))
                       (quoted-input (when new-input
                                       (rxt-quote-pcre new-input))))
                  (this-fn targets recurse zgrep exts
                           default-input quoted-input))))
             (preselection (or (dired-get-filename nil t)
                               (buffer-file-name (current-buffer))))
             (targets   (if targs
                            targs
                          (helm-read-file-name
                           "Search in file(s): "
                           :marked-candidates t
                           :preselect (if helm-ff-transformer-show-only-basename
                                          (helm-basename preselection)
                                        preselection)))))
          (helm-do-grep-1 targets nil nil nil nil use-region-or-symbol-p)))

(defun spacemacs/helm-file-do-grep ()
  "Search in current file with `grep' using a default input."
  (interactive)
  (spacemacs//helm-do-grep-region-or-symbol
   (list (buffer-file-name (current-buffer))) nil))

(defun spacemacs/helm-file-do-grep-region-or-symbol ()
  "Search in current file with `grep' using a default input."
  (interactive)
  (spacemacs//helm-do-grep-region-or-symbol
   (list (buffer-file-name (current-buffer))) t))

(defun spacemacs/helm-files-do-grep ()
  "Search in files with `grep'."
  (interactive)
  (spacemacs//helm-do-grep-region-or-symbol nil nil))

(defun spacemacs/helm-files-do-grep-region-or-symbol ()
  "Search in files with `grep' using a default input."
  (interactive)
  (spacemacs//helm-do-grep-region-or-symbol nil t))

(defun spacemacs/helm-buffers-do-grep ()
  "Search in opened buffers with `grep'."
  (interactive)
  (let ((buffers (cl-loop for buffer in (buffer-list)
                          when (buffer-file-name buffer)
                          collect (buffer-file-name buffer))))
    (spacemacs//helm-do-grep-region-or-symbol buffers nil)))

(defun spacemacs/helm-buffers-do-grep-region-or-symbol ()
  "Search in opened buffers with `grep' with a default input."
  (interactive)
  (let ((buffers (cl-loop for buffer in (buffer-list)
                          when (buffer-file-name buffer)
                          collect (buffer-file-name buffer))))
    (spacemacs//helm-do-grep-region-or-symbol buffers t)))

(defun spacemacs/resume-last-search-buffer ()
  "open last helm-ag or hgrep buffer."
  (interactive)
  (cond ((get-buffer "*helm ag results*")
         (switch-to-buffer-other-window "*helm ag results*"))
        ((get-buffer "*helm-ag*")
         (helm-resume "*helm-ag*"))
        ((get-buffer "*hgrep*")
         (switch-to-buffer-other-window "*hgrep*"))
        (t
         (message "No previous search buffer found"))))

(defun spacemacs/helm-find-files (arg)
  "Custom spacemacs implementation for calling helm-find-files-1.
Removes the automatic guessing of the initial value based on thing at point. "
  (interactive "P")
  (let* ((hist (and arg helm-ff-history (helm-find-files-history)))
         (default-input hist)
         (input (cond ((and (eq major-mode 'dired-mode) default-input)
                       (file-name-directory default-input))
                      ((and (not (string= default-input ""))
                            default-input))
                      (t (expand-file-name (helm-current-directory))))))
    (set-text-properties 0 (length input) nil input)
    (helm-find-files-1 input)))


;; Key bindings

(defmacro spacemacs||set-helm-key (keys func)
  "Define a key bindings for FUNC using KEYS.
Ensure that helm is required before calling FUNC."
  (let ((func-name (intern (format "spacemacs/%s" (symbol-name func)))))
    `(progn
       (defun ,func-name ()
         ,(format "Wrapper to ensure that `helm' is loaded before calling %s."
                  (symbol-name func))
         (interactive)
         (require 'helm)
         (call-interactively ',func))
       (spacemacs/set-leader-keys ,keys ',func-name))))

(defun spacemacs-helm//find-files-edit (candidate)
  "Opens a dired buffer and immediately switches to editable mode."
  (dired (file-name-directory candidate))
  (dired-goto-file candidate)
  (dired-toggle-read-only))

(defun spacemacs-helm/find-files-edit ()
  "Exits helm, opens a dired buffer and immediately switches to editable mode."
  (interactive)
  (helm-exit-and-execute-action 'spacemacs-helm//find-files-edit))
