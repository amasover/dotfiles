;;; spacemacs-config-test.el --- Isolated dotfile contracts -*- lexical-binding: t; -*-

(require 'ert)

(defvar copilot-completion-map)
(defvar copilot-lsp-settings)
(defvar gfm-mode-hook)
(defvar lsp-bash-allowed-shells)
(defvar lsp-pwsh-dir)
(defvar markdown-mode-hook)
(defvar powershell-mode-hook)

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

(ert-deftest dotfiles-spacemacs-registers-system-lsp-hooks ()
  (load dotfiles-spacemacs-file nil nil)
  (let ((gfm-mode-hook nil)
        (markdown-mode-hook nil)
        (powershell-mode-hook nil))
    (dotfiles/configure-language-servers)
    (should (memq #'lsp-deferred gfm-mode-hook))
    (should (memq #'lsp-deferred markdown-mode-hook))
    (should (memq #'lsp-deferred powershell-mode-hook))))

(ert-deftest dotfiles-spacemacs-declares-first-start-lsp-contract ()
  (load dotfiles-spacemacs-file nil nil)
  (dotspacemacs/layers)
  (dotspacemacs/init)
  (should (memq 'github-copilot dotspacemacs-configuration-layers))
  (should (memq 'treemacs dotspacemacs-configuration-layers))
  (should dotspacemacs-line-numbers)
  (should (memq 'lsp-pyright dotspacemacs-additional-packages))
  (should (memq 'lsp-origami dotspacemacs-excluded-packages))
  (should (equal (assq 'yaml dotspacemacs-configuration-layers)
                 '(yaml :variables yaml-enable-lsp t yaml-indent-offset 2)))
  (should (equal (assq 'typescript dotspacemacs-configuration-layers)
                 '(typescript :variables typescript-backend 'lsp
                              typescript-lsp-linter nil)))
  (should (equal (assq 'lua dotspacemacs-configuration-layers)
                 '(lua :variables lua-backend 'lsp
                                  lua-lsp-server 'lua-language-server)))
  (should (equal (assq 'vimscript dotspacemacs-configuration-layers)
                 '(vimscript :variables vimscript-backend 'lsp)))
  (should (equal (assq 'python dotspacemacs-configuration-layers)
                 '(python :variables python-backend 'lsp
                                     python-lsp-server 'pyright)))
  (should (equal (assq 'javascript dotspacemacs-configuration-layers)
                 '(javascript :variables javascript-backend 'lsp
                                         javascript-lsp-linter nil)))
  (should (equal (assq 'shell-scripts dotspacemacs-configuration-layers)
                 '(shell-scripts :variables shell-scripts-backend 'lsp)))
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

(ert-deftest dotfiles-spacemacs-sets-early-lsp-contract ()
  (load dotfiles-spacemacs-file nil nil)
  (let (lsp-bash-allowed-shells lsp-pwsh-dir warning-suppress-types)
    (dotspacemacs/user-init)
    (should (equal lsp-bash-allowed-shells '(sh bash zsh)))
    (should (equal lsp-pwsh-dir "/opt/powershell-editor-services"))))

;;; spacemacs-config-test.el ends here
