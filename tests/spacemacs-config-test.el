;;; spacemacs-config-test.el --- Isolated dotfile contracts -*- lexical-binding: t; -*-

(require 'ert)

(defconst dotfiles-test-root
  (expand-file-name ".." (file-name-directory (or load-file-name buffer-file-name))))
(defconst dotfiles-spacemacs-file
  (or (getenv "SPACEMACS_CONFIG")
      (expand-file-name ".spacemacs" dotfiles-test-root)))

(ert-deftest dotfiles-spacemacs-has-balanced-forms ()
  (with-temp-buffer
    (insert-file-contents dotfiles-spacemacs-file)
    (emacs-lisp-mode)
    (check-parens)))

(ert-deftest dotfiles-spacemacs-loads-without-framework-state ()
  (load dotfiles-spacemacs-file nil nil)
  (should (functionp 'dotspacemacs/layers))
  (should (functionp 'dotspacemacs/init))
  (should (functionp 'dotspacemacs/user-config)))

(ert-deftest dotfiles-spacemacs-declares-first-start-lsp-contract ()
  (load dotfiles-spacemacs-file nil nil)
  (dotspacemacs/layers)
  (dotspacemacs/init)
  (should (memq 'lsp-pyright dotspacemacs-additional-packages))
  (should (memq 'lsp-origami dotspacemacs-excluded-packages))
  (should (eq 'evil dotspacemacs-folding-method)))

(ert-deftest dotfiles-spacemacs-does-not-request-phantom-theme-package ()
  (load dotfiles-spacemacs-file nil nil)
  (dotspacemacs/init)
  (should-not (memq 'omtose-phellack dotspacemacs-themes)))

(ert-deftest dotfiles-spacemacs-suppresses-missing-lexbind-popup ()
  (load dotfiles-spacemacs-file nil nil)
  (let ((warning-suppress-types nil))
    (dotspacemacs/user-init)
    (should (equal warning-suppress-types
                   '((files missing-lexbind-cookie))))))

;;; spacemacs-config-test.el ends here
