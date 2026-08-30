;;; spacemacs-live-smoke.el --- Post-startup GUI contracts -*- lexical-binding: t; -*-

(require 'json)

(let ((failures nil)
      (details nil))
  ;; prog-mode executes the same hook chain that starts Copilot and enables the
  ;; editor behavior users see in source buffers.
  (switch-to-buffer (get-buffer-create "*spacemacs-live-smoke*"))
  (condition-case err
      (prog-mode)
    (error
     (push (format "prog-mode hook exception: %s" (error-message-string err)) failures)))
  (sit-for 0.5)
  (let ((line-numbers
         (or (bound-and-true-p display-line-numbers-mode)
             (bound-and-true-p linum-mode)
             (bound-and-true-p global-display-line-numbers-mode)
             (bound-and-true-p global-linum-mode))))
    (push (format "line-numbers=%s" (and line-numbers t)) details)
    (unless line-numbers
      (push "line numbers disabled in programming buffer" failures)))

  (condition-case err
      (progn
        (require 'treemacs)
        (treemacs)
        (sit-for 0.5)
        (let* ((visibility (treemacs-current-visibility))
               (project-count
                (length (treemacs-workspace->projects (treemacs-current-workspace)))))
          (push (format "treemacs=%s" visibility) details)
          (push (format "treemacs-projects=%d" project-count) details)
          (unless (eq visibility 'visible)
            (push (format "Treemacs visibility is %s" visibility) failures))
          (when (and (getenv "SPACEMACS_EXPECT_TREEMACS_PROJECTS")
                     (= project-count 0))
            (push "Treemacs workspace has no persisted projects" failures))))
    (error
     (push (format "Treemacs exception: %s" (error-message-string err)) failures)))

  (let ((messages (with-current-buffer "*Messages*" (buffer-string))))
    (when (string-match-p
           "\\(?:Error (use-package)\\|Cannot load \\|Debugger entered--Lisp error\\)"
           messages)
      (push "startup messages contain a package/load error" failures)))

  (setq failures (nreverse failures)
        details (nreverse details))
  (let ((result (json-serialize `((ok . ,(if failures :false t))
                                  (failures . ,(vconcat failures))
                                  (details . ,(vconcat details))))))
    (when-let ((path (getenv "SPACEMACS_SMOKE_RESULT")))
      (with-temp-file path
        (insert result "\n")))
    (princ result)
    (princ "\n"))
  (kill-emacs (if failures 1 0)))

;;; spacemacs-live-smoke.el ends here
