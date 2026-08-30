;;; spacemacs-config-test.el --- Isolated dotfile contracts -*- lexical-binding: t; -*-

(require 'ert)

(defvar copilot-completion-map)
(defvar copilot-lsp-settings)

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

(ert-deftest dotfiles-spacemacs-defers-copilot-customization ()
  (load dotfiles-spacemacs-file nil nil)
  (should (functionp 'dotfiles/register-copilot-config))
  (should (functionp 'dotfiles/configure-copilot))
  ;; Registration must be safe before copilot.el defines its keymap.
  (should (ignore-errors (dotfiles/register-copilot-config) t))
  (let ((copilot-completion-map (make-sparse-keymap))
        copilot-lsp-settings)
    (dotfiles/configure-copilot)
    (should (eq (lookup-key copilot-completion-map (kbd "<C-tab>"))
                'copilot-accept-completion))
    (should (eq (lookup-key copilot-completion-map (kbd "C-TAB"))
                'copilot-accept-completion))
    (should (equal copilot-lsp-settings
                   '(:github (:copilot (:selectedCompletionModel "gpt-41-copilot")))))))

(ert-deftest dotfiles-setup-does-not-shadow-copilot-server-command ()
  (let ((exec-path (list (expand-file-name ".local/bin/setup" dotfiles-test-root))))
    (should-not (executable-find "copilot-language-server"))))

(ert-deftest dotfiles-spacemacs-declares-first-start-lsp-contract ()
  (load dotfiles-spacemacs-file nil nil)
  (dotspacemacs/layers)
  (dotspacemacs/init)
  (should (memq 'github-copilot dotspacemacs-configuration-layers))
  (should (memq 'treemacs dotspacemacs-configuration-layers))
  (should dotspacemacs-line-numbers)
  (should (memq 'lsp-pyright dotspacemacs-additional-packages))
  (should (memq 'lsp-origami dotspacemacs-excluded-packages))
  (should (eq 'evil dotspacemacs-folding-method)))

(ert-deftest dotfiles-spacemacs-does-not-request-phantom-theme-package ()
  (load dotfiles-spacemacs-file nil nil)
  (dotspacemacs/init)
  (should-not (memq 'omtose-phellack dotspacemacs-themes)))

;;; spacemacs-config-test.el ends here
