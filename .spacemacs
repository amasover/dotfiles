;; -*- mode: emacs-lisp; lexical-binding: t -*-
;; This file is loaded by Spacemacs at startup.
;; It must be stored in your home directory.

(defun dotspacemacs/layers ()
  "Layer configuration:
This function should only modify configuration layer settings."
  (setq-default
   ;; Base distribution to use. This is a layer contained in the directory
   ;; `+distribution'. For now available distributions are `spacemacs-base'
   ;; or `spacemacs'. (default 'spacemacs)
   dotspacemacs-distribution 'spacemacs

   ;; Lazy installation of layers (i.e. layers are installed only when a file
   ;; with a supported type is opened). Possible values are `all', `unused'
   ;; and `nil'. `unused' will lazy install only unused layers (i.e. layers
   ;; not listed in variable `dotspacemacs-configuration-layers'), `all' will
   ;; lazy install any layer that support lazy installation even the layers
   ;; listed in `dotspacemacs-configuration-layers'. `nil' disable the lazy
   ;; installation feature and you have to explicitly list a layer in the
   ;; variable `dotspacemacs-configuration-layers' to install it.
   ;; (default 'unused)
   dotspacemacs-enable-lazy-installation 'unused

   ;; If non-nil then Spacemacs will ask for confirmation before installing
   ;; a layer lazily. (default t)
   dotspacemacs-ask-for-lazy-installation t

   ;; If non-nil layers with lazy install support are lazy installed.
   ;; List of additional paths where to look for configuration layers.
   ;; Paths must have a trailing slash (i.e. `~/.mycontribs/')
   dotspacemacs-configuration-layer-path '()

   ;; List of configuration layers to load.
   dotspacemacs-configuration-layers
   '(ansible
     php
     windows-scripts
     docker
     (yaml :variables
           yaml-indent-offset 2)
     typescript
     csv
     nginx
     csharp
     terraform
     auto-completion
     github-copilot
     html
     lsp
     rust
     (go :variables
         godoc-at-point-fuction 'godoc-gogetdoc
         go-format-before-save t)
     vimscript
     python
     ;; ----------------------------------------------------------------
     ;; Example of useful layers you may want to use right away.
     ;; Uncomment some layer names and press `SPC f e R' (Vim style) or
     ;; `M-m f e R' (Emacs style) to install them.
     ;; ----------------------------------------------------------------
     helm
     javascript
     (auto-completion :variables
                      auto-completion-enable-sort-by-usage t)
     better-defaults
     emacs-lisp
     git
     (markdown :variables
               markdown-live-preview-engine 'vmd)
     ;;multiple-cursors
     (org :variables
          org-default-notes-file "~/TODO.org")
     (shell :variables
            shell-default-height 30
            shell-default-position 'bottom
            shell-default-shell 'multi-term
            shell-default-term-shell "/usr/bin/zsh")
     ;; wakatime
     themes-megapack
     ;; spell-checking
     syntax-checking
     treemacs
     version-control
     tree-sitter
     ;; (llm-client :variables
     ;;             llm-client-enable-gptel t)
     )

   ;; List of additional packages that will be installed without being wrapped
   ;; in a layer (generally the packages are installed only and should still be
   ;; loaded using load/require/use-package in the user-config section below in
   ;; this file). If you need some configuration for these packages, then
   ;; consider creating a layer. You can also put the configuration in
   ;; `dotspacemacs/user-config'. To use a local version of a package, use the
   ;; `:location' property: '(your-package :location "~/path/to/your-package/")
   ;; Also include the dependencies as they will not be resolved automatically.
   dotspacemacs-additional-packages '(
                                      ;; Install quelpa and use-package to workaround current issue in Nord.
                                      ;; Rest of the fix is at the bottom of init.el
                                      ;; See https://github.com/nordtheme/emacs/pull/131
                                      use-package
                                      quelpa
                                        ;nord-theme
                                        ;majapahit-theme
                                      (groovy-mode :location elpa)
                                      ;;
                                      all-the-icons
                                      lsp-treemacs
                                      go-autocomplete
                                      vlf
                                      editorconfig
                                      nvm
                                      aider
                                      aidermacs
                                      terraform-mode
                                      markdown-mode
                                        ;terraform-mode
                                        ;hcl-mode
                                        ;company-terraform
                                        ;company-lsp
                                      )


   ;; A list of packages that cannot be updated.
   dotspacemacs-frozen-packages '()

   ;; A list of packages that will not be installed and loaded.
   dotspacemacs-excluded-packages '( firebelly-theme
                                     niflheim-theme
                                     pastels-on-dark-theme
                                     tronesque-theme
                                     zonokai-theme
                                     phpcbf)
   ;; Defines the behaviour of Spacemacs when installing packages.
   ;; Possible values are `used-only', `used-but-keep-unused' and `all'.
   ;; `used-only' installs only explicitly used packages and deletes any unused
   ;; packages as well as their unused dependencies. `used-but-keep-unused'
   ;; installs only the used packages but won't delete unused ones. `all'
   ;; installs *all* packages supported by Spacemacs and never uninstalls them.
   ;; (default is `used-only')
   dotspacemacs-install-packages 'used-only))

(defun dotspacemacs/init ()
  "Initialization:
This function is called at the very beginning of Spacemacs startup,
before layer configuration.
It should only modify the values of Spacemacs settings."
  ;; This setq-default sexp is an exhaustive list of all the supported
  ;; spacemacs settings.
  (setq-default
   ;; If non-nil then enable support for the portable dumper. You'll need to
   ;; compile Emacs 27 from source following the instructions in file
   ;; EXPERIMENTAL.org at to root of the git repository.
   ;;
   ;; WARNING: pdumper does not work with Native Compilation, so it's disabled
   ;; regardless of the following setting when native compilation is in effect.
   ;;
   ;; (default nil)
   dotspacemacs-enable-emacs-pdumper nil

   ;; File path pointing to emacs 27.1 executable compiled with support
   ;; for the portable dumper (this is currently the branch pdumper).
   ;; (default "emacs-27.0.50")
   dotspacemacs-emacs-pdumper-executable-file "emacs-27.0.50"

   ;; Name of the Spacemacs dump file. This is the file will be created by the
   ;; portable dumper in the cache directory under dumps sub-directory.
   ;; To load it when starting Emacs add the parameter `--dump-file'
   ;; when invoking Emacs 27.1 executable on the command line, for instance:
   ;;   ./emacs --dump-file=$HOME/.emacs.d/.cache/dumps/spacemacs-27.1.pdmp
   ;; (default (format "spacemacs-%s.pdmp" emacs-version))
   dotspacemacs-emacs-dumper-dump-file (format "spacemacs-%s.pdmp" emacs-version)

   ;; If non-nil ELPA repositories are contacted via HTTPS whenever it's
   ;; possible. Set it to nil if you have no way to use HTTPS in your
   ;; environment, otherwise it is strongly recommended to let it set to t.
   ;; This variable has no effect if Emacs is launched with the parameter
   ;; `--insecure' which forces the value of this variable to nil.
   ;; (default t)
   dotspacemacs-elpa-https t

   ;; Maximum allowed time in seconds to contact an ELPA repository.
   ;; (default 5)
   dotspacemacs-elpa-timeout 5

   ;; Set `gc-cons-threshold' and `gc-cons-percentage' when startup finishes.
   ;; This is an advanced option and should not be changed unless you suspect
   ;; performance issues due to garbage collection operations.
   ;; (default '(100000000 0.1))
   dotspacemacs-gc-cons '(100000000 0.1)

   ;; Set `read-process-output-max' when startup finishes.
   ;; This defines how much data is read from a foreign process.
   ;; Setting this >= 1 MB should increase performance for lsp servers
   ;; in emacs 27.
   ;; (default (* 1024 1024))
   dotspacemacs-read-process-output-max (* 1024 1024)

   ;; If non-nil then Spacelpa repository is the primary source to install
   ;; a locked version of packages. If nil then Spacemacs will install the
   ;; latest version of packages from MELPA. Spacelpa is currently in
   ;; experimental state please use only for testing purposes.
   ;; (default nil)
   dotspacemacs-use-spacelpa nil

   ;; If non-nil then verify the signature for downloaded Spacelpa archives.
   ;; (default nil)
   dotspacemacs-verify-spacelpa-archives nil

   ;; If non-nil then spacemacs will check for updates at startup
   ;; when the current branch is not `develop'. Note that checking for
   ;; new versions works via git commands, thus it calls GitHub services
   ;; whenever you start Emacs. (default nil)
   dotspacemacs-check-for-update t
   ;; If non-nil, a form that evaluates to a package directory. For example, to
   ;; use different package directories for different Emacs versions, set this
   ;; to `emacs-version'.
   dotspacemacs-elpa-subdirectory nil
   ;; One of `vim', `emacs' or `hybrid'.
   ;; `hybrid' is like `vim' except that `insert state' is replaced by the
   ;; `hybrid state' with `emacs' key bindings. The value can also be a list
   ;; with `:variables' keyword (similar to layers). Check the editing styles
   ;; section of the documentation for details on available variables.
   ;; (default 'vim)
   dotspacemacs-editing-style 'vim

   ;; If non-nil show the version string in the Spacemacs buffer. It will
   ;; appear as (spacemacs version)@(emacs version)
   ;; (default t)
   dotspacemacs-startup-buffer-show-version t

   ;; Specify the startup banner. Default value is `official', it displays
   ;; the official spacemacs logo. An integer value is the index of text
   ;; banner, `random' chooses a random text banner in `core/banners'
   ;; directory. A string value must be a path to an image format supported
   ;; by your Emacs build.
   ;; If the value is nil then no banner is displayed. (default 'official)
   dotspacemacs-startup-banner 'random

   ;; Scale factor controls the scaling (size) of the startup banner. Default
   ;; value is `auto' for scaling the logo automatically to fit all buffer
   ;; contents, to a maximum of the full image height and a minimum of 3 line
   ;; heights. If set to a number (int or float) it is used as a constant
   ;; scaling factor for the default logo size.
   dotspacemacs-startup-banner-scale 'auto

   ;; List of items to show in startup buffer or an association list of
   ;; the form `(list-type . list-size)`. If nil then it is disabled.
   ;; Possible values for list-type are:
   ;; `recents' `recents-by-project' `bookmarks' `projects' `agenda' `todos'.
   ;; List sizes may be nil, in which case
   ;; `spacemacs-buffer-startup-lists-length' takes effect.
   ;; The exceptional case is `recents-by-project', where list-type must be a
   ;; pair of numbers, e.g. `(recents-by-project . (7 .  5))', where the first
   ;; number is the project limit and the second the limit on the recent files
   ;; within a project.
   dotspacemacs-startup-lists '((recents . 5)
                                (projects . 7))

   ;; True if the home buffer should respond to resize events. (default t)
   dotspacemacs-startup-buffer-responsive t

   ;; Show numbers before the startup list lines. (default t)
   dotspacemacs-show-startup-list-numbers t

   ;; The minimum delay in seconds between number key presses. (default 0.4)
   dotspacemacs-startup-buffer-multi-digit-delay 0.4

   ;; If non-nil, show file icons for entries and headings on Spacemacs home buffer.
   ;; This has no effect in terminal or if "all-the-icons" package or the font
   ;; is not installed. (default nil)
   dotspacemacs-startup-buffer-show-icons nil

   ;; Default major mode for a new empty buffer. Possible values are mode
   ;; names such as `text-mode'; and `nil' to use Fundamental mode.
   ;; (default `text-mode')
   dotspacemacs-new-empty-buffer-major-mode 'text-mode

   ;; Default major mode of the scratch buffer (default `text-mode')
   dotspacemacs-scratch-mode 'text-mode

   ;; If non-nil, *scratch* buffer will be persistent. Things you write down in
   ;; *scratch* buffer will be saved and restored automatically.
   dotspacemacs-scratch-buffer-persistent nil

   ;; If non-nil, `kill-buffer' on *scratch* buffer
   ;; will bury it instead of killing.
   dotspacemacs-scratch-buffer-unkillable nil

   ;; Initial message in the scratch buffer, such as "Welcome to Spacemacs!"
   ;; (default nil)
   dotspacemacs-initial-scratch-message nil

   ;; List of themes, the first of the list is loaded when spacemacs starts.
   ;; Press `SPC T n' to cycle to the next theme in the list (works great
   ;; with 2 themes variants, one dark and one light)
   dotspacemacs-themes '(
                         nord
                         dracula
                         darktooth
                         jazz
                         molokai
                         solarized-dark
                         ujelly
                         spacemacs-dark
                         spacemacs-light
                         seti
                         planet
                         flatui
                         spacegray
                         monokai
                         apropospriate-light
                         lush
                         naquadah
                         obsidian
                         omtose-phellack
                         reverse
                         smyx
                         soothe
                         )

   ;; Set the theme for the Spaceline. Supported themes are `spacemacs',
   ;; `all-the-icons', `custom', `doom', `vim-powerline' and `vanilla'. The
   ;; first three are spaceline themes. `doom' is the doom-emacs mode-line.
   ;; `vanilla' is default Emacs mode-line. `custom' is a user defined themes,
   ;; refer to the DOCUMENTATION.org for more info on how to create your own
   ;; spaceline theme. Value can be a symbol or list with additional properties.
   ;; (default '(spacemacs :separator wave :separator-scale 1.5))
   dotspacemacs-mode-line-theme '(spacemacs :separator wave :separator-scale 1.5)

   ;; If non nil the cursor color matches the state color in GUI Emacs.
   dotspacemacs-colorize-cursor-according-to-state t

   ;; Default font, or prioritized list of fonts. `powerline-scale' allows to
   ;; quickly tweak the mode-line size to make separators look not too crappy.
   ;; dotspacemacs-default-font '("Source Code Pro for Powerline"
   dotspacemacs-default-font '("Hack"
                               :size 16
                               :weight normal
                               :width normal
                               :powerline-scale 1.2)
   ;; The leader key (default "SPC")
   dotspacemacs-leader-key "SPC"

   ;; The key used for Emacs commands `M-x' (after pressing on the leader key).
   ;; (default "SPC")
   dotspacemacs-emacs-command-key "SPC"

   ;; The key used for Vim Ex commands (default ":")
   dotspacemacs-ex-command-key ":"

   ;; The leader key accessible in `emacs state' and `insert state'
   ;; (default "M-m")
   dotspacemacs-emacs-leader-key "M-m"

   ;; Major mode leader key is a shortcut key which is the equivalent of
   ;; pressing `<leader> m`. Set it to `nil` to disable it. (default ",")
   dotspacemacs-major-mode-leader-key ","

   ;; Major mode leader key accessible in `emacs state' and `insert state'.
   ;; (default "C-M-m" for terminal mode, "<M-return>" for GUI mode).
   ;; Thus M-RET should work as leader key in both GUI and terminal modes.
   ;; C-M-m also should work in terminal mode, but not in GUI mode.
   dotspacemacs-major-mode-emacs-leader-key (if window-system "<M-return>" "C-M-m")

   ;; These variables control whether separate commands are bound in the GUI to
   ;; the key pairs `C-i', `TAB' and `C-m', `RET'.
   ;; Setting it to a non-nil value, allows for separate commands under `C-i'
   ;; and TAB or `C-m' and `RET'.
   ;; In the terminal, these pairs are generally indistinguishable, so this only
   ;; works in the GUI. (default nil)
   dotspacemacs-distinguish-gui-tab nil

   ;; Name of the default layout (default "Default")
   dotspacemacs-default-layout-name "Default"

   ;; If non-nil the default layout name is displayed in the mode-line.
   ;; (default nil)
   dotspacemacs-display-default-layout nil

   ;; If non-nil then the last auto saved layouts are resumed automatically upon
   ;; start. (default nil)
   dotspacemacs-auto-resume-layouts nil

   ;; If non-nil, auto-generate layout name when creating new layouts. Only has
   ;; effect when using the "jump to layout by number" commands. (default nil)
   dotspacemacs-auto-generate-layout-names nil

   ;; Size (in MB) above which spacemacs will prompt to open the large file
   ;; literally to avoid performance issues. Opening a file literally means that
   ;; no major mode or minor modes are active. (default is 1)
   dotspacemacs-large-file-size 1

   ;; Location where to auto-save files. Possible values are `original' to
   ;; auto-save the file in-place, `cache' to auto-save the file to another
   ;; file stored in the cache directory and `nil' to disable auto-saving.
   ;; (default 'cache)
   dotspacemacs-auto-save-file-location 'cache

   ;; Maximum number of rollback slots to keep in the cache. (default 5)
   dotspacemacs-max-rollback-slots 5

   ;; If non-nil, the paste transient-state is enabled. While enabled, after you
   ;; paste something, pressing `C-j' and `C-k' several times cycles through the
   ;; elements in the `kill-ring'. (default nil)
   dotspacemacs-enable-paste-transient-state nil

   ;; Which-key delay in seconds. The which-key buffer is the popup listing
   ;; the commands bound to the current keystroke sequence. (default 0.4)
   dotspacemacs-which-key-delay 0.4

   ;; Which-key frame position. Possible values are `right', `bottom' and
   ;; `right-then-bottom'. right-then-bottom tries to display the frame to the
   ;; right; if there is insufficient space it displays it at the bottom.
   ;; (default 'bottom)
   dotspacemacs-which-key-position 'bottom

   ;; Control where `switch-to-buffer' displays the buffer. If nil,
   ;; `switch-to-buffer' displays the buffer in the current window even if
   ;; another same-purpose window is available. If non-nil, `switch-to-buffer'
   ;; displays the buffer in a same-purpose window even if the buffer can be
   ;; displayed in the current window. (default nil)
   dotspacemacs-switch-to-buffer-prefers-purpose nil

   ;; If non-nil a progress bar is displayed when spacemacs is loading. This
   ;; may increase the boot time on some systems and emacs builds, set it to
   ;; nil to boost the loading time. (default t)
   dotspacemacs-loading-progress-bar t

   ;; If non-nil the frame is fullscreen when Emacs starts up. (default nil)
   ;; (Emacs 24.4+ only)
   dotspacemacs-fullscreen-at-startup nil

   ;; If non-nil `spacemacs/toggle-fullscreen' will not use native fullscreen.
   ;; Use to disable fullscreen animations in OSX. (default nil)
   dotspacemacs-fullscreen-use-non-native nil

   ;; If non-nil the frame is maximized when Emacs starts up.
   ;; Takes effect only if `dotspacemacs-fullscreen-at-startup' is nil.
   ;; (default t) (Emacs 24.4+ only)
   dotspacemacs-maximized-at-startup t

   ;; If non-nil the frame is undecorated when Emacs starts up. Combine this
   ;; variable with `dotspacemacs-maximized-at-startup' to obtain fullscreen
   ;; without external boxes. Also disables the internal border. (default nil)
   dotspacemacs-undecorated-at-startup nil

   ;; A value from the range (0..100), in increasing opacity, which describes
   ;; the transparency level of a frame when it's active or selected.
   ;; Transparency can be toggled through `toggle-transparency'. (default 90)
   dotspacemacs-active-transparency 90

   ;; A value from the range (0..100), in increasing opacity, which describes
   ;; the transparency level of a frame when it's inactive or deselected.
   ;; Transparency can be toggled through `toggle-transparency'. (default 90)
   dotspacemacs-inactive-transparency 90

   ;; A value from the range (0..100), in increasing opacity, which describes the
   ;; transparency level of a frame background when it's active or selected. Transparency
   ;; can be toggled through `toggle-background-transparency'. (default 90)
   dotspacemacs-background-transparency 90

   ;; If non-nil show the titles of transient states. (default t)
   dotspacemacs-show-transient-state-title t

   ;; If non-nil show the color guide hint for transient state keys. (default t)
   dotspacemacs-show-transient-state-color-guide t

   ;; If non-nil unicode symbols are displayed in the mode line.
   ;; If you use Emacs as a daemon and wants unicode characters only in GUI set
   ;; the value to quoted `display-graphic-p'. (default t)
   dotspacemacs-mode-line-unicode-symbols t

   ;; If non-nil smooth scrolling (native-scrolling) is enabled. Smooth
   ;; scrolling overrides the default behavior of Emacs which recenters point
   ;; when it reaches the top or bottom of the screen. (default t)
   dotspacemacs-smooth-scrolling t

   ;; Show the scroll bar while scrolling. The auto hide time can be configured
   ;; by setting this variable to a number. (default t)
   dotspacemacs-scroll-bar-while-scrolling t

   ;; Control line numbers activation.
   ;; If set to `t', `relative' or `visual' then line numbers are enabled in all
   ;; `prog-mode' and `text-mode' derivatives. If set to `relative', line
   ;; numbers are relative. If set to `visual', line numbers are also relative,
   ;; but only visual lines are counted. For example, folded lines will not be
   ;; counted and wrapped lines are counted as multiple lines.
   ;; This variable can also be set to a property list for finer control:
   ;; '(:relative nil
   ;;   :disabled-for-modes dired-mode
   ;;                       doc-view-mode
   ;;                       markdown-mode
   ;;                       org-mode
   ;;                       pdf-view-mode
   ;;                       text-mode
   ;;   :size-limit-kb 1000)
   ;; (default nil)
   dotspacemacs-mode-line-theme 'spacemacs
   dotspacemacs-line-numbers t

   ;; Code folding method. Possible values are `evil', `origami' and `vimish'.
   ;; (default 'evil)
   dotspacemacs-folding-method 'evil

   ;; If non-nil and `dotspacemacs-activate-smartparens-mode' is also non-nil,
   ;; `smartparens-strict-mode' will be enabled in programming modes.
   ;; (default nil)
   dotspacemacs-smartparens-strict-mode nil

   ;; If non-nil smartparens-mode will be enabled in programming modes.
   ;; (default t)
   dotspacemacs-activate-smartparens-mode t

   ;; If non-nil pressing the closing parenthesis `)' key in insert mode passes
   ;; over any automatically added closing parenthesis, bracket, quote, etc…
   ;; This can be temporary disabled by pressing `C-q' before `)'. (default nil)
   dotspacemacs-smart-closing-parenthesis nil

   ;; Select a scope to highlight delimiters. Possible values are `any',
   ;; `current', `all' or `nil'. Default is `all' (highlight any scope and
   ;; emphasis the current one). (default 'all)
   dotspacemacs-highlight-delimiters 'all

   ;; If non-nil, start an Emacs server if one is not already running.
   ;; (default nil)
   dotspacemacs-enable-server nil

   ;; Set the emacs server socket location.
   ;; If nil, uses whatever the Emacs default is, otherwise a directory path
   ;; like \"~/.emacs.d/server\". It has no effect if
   ;; `dotspacemacs-enable-server' is nil.
   ;; (default nil)
   dotspacemacs-server-socket-dir nil

   ;; If non-nil, advise quit functions to keep server open when quitting.
   ;; (default nil)
   dotspacemacs-persistent-server nil

   ;; List of search tool executable names. Spacemacs uses the first installed
   ;; tool of the list. Supported tools are `rg', `ag', `pt', `ack' and `grep'.
   ;; (default '("rg" "ag" "pt" "ack" "grep"))
   dotspacemacs-search-tools '("rg" "ag" "ack" "grep")

   ;; Format specification for setting the frame title.
   ;; %a - the `abbreviated-file-name', or `buffer-name'
   ;; %t - `projectile-project-name'
   ;; %I - `invocation-name'
   ;; %S - `system-name'
   ;; %U - contents of $USER
   ;; %b - buffer name
   ;; %f - visited file name
   ;; %F - frame name
   ;; %s - process status
   ;; %p - percent of buffer above top of window, or Top, Bot or All
   ;; %P - percent of buffer above bottom of window, perhaps plus Top, or Bot or All
   ;; %m - mode name
   ;; %n - Narrow if appropriate
   ;; %z - mnemonics of buffer, terminal, and keyboard coding systems
   ;; %Z - like %z, but including the end-of-line format
   ;; If nil then Spacemacs uses default `frame-title-format' to avoid
   ;; performance issues, instead of calculating the frame title by
   ;; `spacemacs/title-prepare' all the time.
   ;; (default "%I@%S")
   dotspacemacs-frame-title-format "%I@%S"

   ;; Format specification for setting the icon title format
   ;; (default nil - same as frame-title-format)
   dotspacemacs-icon-title-format nil

   ;; Color highlight trailing whitespace in all prog-mode and text-mode derived
   ;; modes such as c++-mode, python-mode, emacs-lisp, html-mode, rst-mode etc.
   ;; (default t)
   dotspacemacs-show-trailing-whitespace t

   ;; Delete whitespace while saving buffer. Possible values are `all'
   ;; to aggressively delete empty line and long sequences of whitespace,
   ;; `trailing' to delete only the whitespace at end of lines, `changed' to
   ;; delete only whitespace for changed lines or `nil' to disable cleanup.
   ;; (default nil)
   dotspacemacs-whitespace-cleanup nil

   ;; If non-nil activate `clean-aindent-mode' which tries to correct
   ;; virtual indentation of simple modes. This can interfere with mode specific
   ;; indent handling like has been reported for `go-mode'.
   ;; If it does deactivate it here.
   ;; (default t)
   dotspacemacs-use-clean-aindent-mode t

   ;; Accept SPC as y for prompts if non-nil. (default nil)
   dotspacemacs-use-SPC-as-y nil

   ;; If non-nil shift your number row to match the entered keyboard layout
   ;; (only in insert state). Currently supported keyboard layouts are:
   ;; `qwerty-us', `qwertz-de' and `querty-ca-fr'.
   ;; New layouts can be added in `spacemacs-editing' layer.
   ;; (default nil)
   dotspacemacs-swap-number-row nil

   ;; Either nil or a number of seconds. If non-nil zone out after the specified
   ;; number of seconds. (default nil)
   dotspacemacs-zone-out-when-idle nil

   ;; Run `spacemacs/prettify-org-buffer' when
   ;; visiting README.org files of Spacemacs.
   ;; (default nil)
   dotspacemacs-pretty-docs nil

   ;; If nil the home buffer shows the full path of agenda items
   ;; and todos. If non-nil only the file name is shown.
   dotspacemacs-home-shorten-agenda-source nil

   ;; If non-nil then byte-compile some of Spacemacs files.
   dotspacemacs-byte-compile nil))

(defun dotspacemacs/user-env ()
  "Environment variables setup.
This function defines the environment variables for your Emacs session. By
default it calls `spacemacs/load-spacemacs-env' which loads the environment
variables declared in `~/.spacemacs.env' or `~/.spacemacs.d/.spacemacs.env'.
See the header of this file for more information."
  (spacemacs/load-spacemacs-env)
  )

(defun dotspacemacs/user-init ()
  "Initialization for user code:
This function is called immediately after `dotspacemacs/init', before layer
configuration.
It is mostly for variables that should be set before packages are loaded.
If you are unsure, try setting them in `dotspacemacs/user-config' first."
  )


(defun dotspacemacs/user-load ()
  "Library to load while dumping.
This function is called only while dumping Spacemacs configuration. You can
`require' or `load' the libraries of your choice that will be included in the
dump."
  )


(defun dotspacemacs/user-config ()
  "Configuration for user code:
This function is called at the very end of Spacemacs startup, after layer
configuration.
Put your configuration code here, except for variables that should be set
before packages are loaded."

  ;;Treemacs bulk
  (evil-define-key 'treemacs treemacs-mode-map (kbd "M") #'treemacs-bulk-file-actions)

  (setq  x-meta-keysym 'super
         x-super-keysym 'meta)

  ;; Ignore warnings
  ;; FIXME should not remain on forever
  (setq warning-minimum-level :emergency)

  ;; All env vars from shell may need to be loaded at once.
  ;; See https://github.com/purcell/exec-path-from-shell/issues/63
  ;; Needed for magit to use ssh-agent: "SSH_AGENT_PID" "SSH_AUTH_SOCK"
  (setq exec-path-from-shell-variables '("WAKA_API_KEY" "SSH_AGENT_PID" "SSH_AUTH_SOCK" "GOPATH" "GOROOT"))
  ;;(setq wakatime-cli-path "$HOME/.local/bin/wakatime")

  ;;  (use-package nvm)
  ;;  (nvm-use "14.17.1")

  ;;(setq mouse-wheel-scroll-amount '(1 ((shift) . 1))) ;; one line at a time

  ;;(setq mouse-wheel-progressive-speed nil) ;; don't accelerate scrolling

  (setq mouse-wheel-follow-mouse 't) ;; scroll window under mouse

  (setq scroll-step 1) ;; keyboard scroll one line at a time

  (setq scroll-preserve-screen-position t
        scroll-conservatively 0
        maximum-scroll-margin 0.5
        scroll-margin 99999)

  ;; Workaround for helm-ag propertizing a read-only Helm buffer.
  (with-eval-after-load 'helm-ag
    (defun dotfiles/helm-ag--do-ag-propertize-inhibit-read-only (orig-fun input)
      (let ((inhibit-read-only t))
        (funcall orig-fun input)))
    (unless (advice-member-p #'dotfiles/helm-ag--do-ag-propertize-inhibit-read-only
                             'helm-ag--do-ag-propertize)
      (advice-add 'helm-ag--do-ag-propertize
                  :around #'dotfiles/helm-ag--do-ag-propertize-inhibit-read-only)))

  ;; Workaround for find-replace bug. See:
  ;; https://github.com/syl20bnr/spacemacs/issues/10938
                                        ;(setq frame-title-format nil)

  (add-hook 'json-mode-hook
            (lambda ()
              (make-local-variable 'js-indent-level)
              (setq js-indent-level 2)))

  (add-hook 'yaml-mode-hook
            (lambda ()
              (make-local-variable 'yaml-indent-offset)
              (setq yaml-indent-offset 2)))

                                        ;(setq indent-tabs-mode t)
                                        ;(setq tab-width 2)
                                        ;(setq indent-line-function 'indent-relative)

  ;; don't garbage collect based on cons count
  (setq gc-cons-threshold 10000000000)
  (defun garbage-collect (&rest args)
    (message "trying to garbage collect. probably you want to quit emacs."))

  ;; LSP mode

  (setq lsp-ui-sideline-diagnostic-max-lines 2)
  (setq lsp-ui-sideline-diagnostic-max-line-length 500)

  ;; az pipelines
  (add-hook 'yaml-mode-hook #'lsp-deferred)
  (let ((az-pipe-schema "https://raw.githubusercontent.com/microsoft/azure-pipelines-vscode/master/service-schema.json"))
    (setq lsp-yaml-schemas (make-hash-table))
    (puthash az-pipe-schema ["steps/*" "azure-pipelines*" "pipelines/**/*.yml"] lsp-yaml-schemas))

  (let ((argo-schema "https://raw.githubusercontent.com/argoproj/argo-workflows/main/api/jsonschema/schema.json"))
    (setq lsp-yaml-schemas (make-hash-table))
    (puthash argo-schema ["argo/**/*.yml" "argo/**/*.yaml"] lsp-yaml-schemas))

  ;; (let ((atmos-schema "https://atmos.tools/schemas/atmos/atmos-manifest/1.0/atmos-manifest.json"))
  ;;   (setq lsp-yaml-schemas (make-hash-table))
  ;;   (puthash atmos-schema ["stacks/*"] lsp-yaml-schemas))

  (defun is-az-pipelines ()
    (if (or (string-match-p (regexp-quote "azure-pipelines") buffer-file-name)
            (string-match-p (regexp-quote "steps/") buffer-file-name)
            (string-match-p (regexp-quote "pipelines/") buffer-file-name))
        (setq lsp-yaml-server-command '("azure-pipelines-language-server" "--stdio"))
      (setq lsp-yaml-server-command '("yaml-language-server" "--stdio"))))
  (add-hook 'yaml-mode-hook 'is-az-pipelines)
  (add-hook 'csharp-mode-hook #'lsp-deferred)

  (setq yaml-indent-offset 2)

  (print(string-match-p (regexp-quote "pipelines/") "pipelines/odp-templates/test.yml"))
  (print "test")

  ;; Python
  ;; (use-package lsp-python
  ;;   :ensure t
  ;;   :config
  ;;   (add-hook 'python-mode-hook (lambda ()
  ;;                                 (pyvenv-mode t)
  ;;                                 (lsp-python-enable))))
  (setq lsp-pyright-multi-root nil)
  (use-package lsp-pyright
    :ensure t
    :hook (python-mode . (lambda ()
                           (require 'lsp-pyright)
                           (lsp))))  ; or lsp-deferred

  ;;  (defun )

  ;; Terraform
  ;; (add-to-list 'lsp-language-id-configuration '(terraform-mode . "terraform"))

  (require 'lsp-mode)
  ;; (lsp-register-client
  ;;  (make-lsp-client :new-connection (lsp-stdio-connection '("/home/aaron/.bin/terraform-lsp"
  ;;                                                           "--debug"
  ;;                                                           "--debug-jrpc2"
  ;;                                                           "--enable-log-file"
  ;;                                                           "--enable-log-jrpc2-file"
  ;;                                                           "--log-location" "/home/aaron/terraform-lsp-logs/log.txt"
  ;;                                                           "--log-jrpc2-location" "/home/aaron/terraform-lsp-logs/jrpc2-log.txt"))
  ;;                   :major-modes '(terraform-mode)
  ;;                   :server-id 'terraform-ls))

                                        ;(add-to-list 'lsp-language-id-configuration '(terraform-mode . "terraform"))
  ;; (lsp-register-client
  ;;  (make-lsp-client :new-connection (lsp-stdio-connection '("/usr/bin/terraform-ls" "serve"))
  ;;                   :major-modes '(terraform-mode)
  ;;                   :server-id 'terraform-ls))


                                        ;(add-hook 'terraform-mode-hook #'lsp-deferred)
                                        ;(setq lsp-terraform-server '("/home/aaron/.bin/terraform-lsp"))
                                        ;(setq lsp-terraform-server '("/usr/bin/terraform-ls"))
                                        ;(add-hook 'terraform-mode-hook (lambda () (delete 'company-terraform 'company-backends)))
                                        ;(require 'company-lsp)
  ;;(require 'company-terraform)
  ;; (add-hook 'lsp-mode-hook
  ;;           (lambda () (add-to-list 'company-backends 'company-lsp)))
  ;;(add-hook 'terraform-mode-hook
  ;;(lambda () (add-to-list 'company-backends 'company-terraform)))
  (add-hook 'lsp-mode-hook
            (lambda () (add-to-list 'company-backends 'company-capf)))
                                        ;(push 'company-lsp company-backends)


  ;; Install quelpa stuff for to workaround current issue in Nord.
  ;; Rest of the fix is at the bottom of init.el
  ;; See https://github.com/nordtheme/emacs/pull/131
  ;; (quelpa
  ;;  '(quelpa-use-package
  ;;    :fetcher git
  ;;    :url "https://github.com/quelpa/quelpa-use-package.git"))

  ;; Set leader key for Aidermacs
  (spacemacs/set-leader-keys "aa" 'aidermacs-transient-menu) ; Example binding SPC a a
  (setq aidermacs-watch-files t)
  (setq aidermacs-backend 'vterm)

  ;; aider
  (require 'aider)
  (require 'aider-helm)
  (use-package aider
    :config
    (global-set-key (kbd "C-c i") 'aider-transient-menu) ;; for wider screen
    ;; or use aider-transient-menu-2cols / aider-transient-menu-1col, for narrow screen
    ;; auto revert buffer
    (global-auto-revert-mode 1)
    (auto-revert-mode 1))

  ;; ai junk
  ;; (setq gptel-model 'gpt-4.1
  ;;       gptel-backend (gptel-make-gh-copilot "Copilot"))

  ;; (add-to-list 'gptel-prompt-prefix-alist `(org-mode . ,(concat "*** gjg " (format-time-string "[%Y-%m-%d]") "\n")))

  ;; (require 'gptel)
  ;;(require 'gptel-curl)
  ;; (require 'gptel-transient)
  ;; (require 'gptel-integrations)

  ;; (use-package init-gptel
  ;;   :load-path "~/.emacs.d/lisp/init-gptel.el")

  ;;(add-to-list 'auto-mode-alist '("\\.*\\'" . copilot-mode))
  (define-key copilot-completion-map (kbd "<C-tab>") 'copilot-accept-completion)
  (define-key copilot-completion-map (kbd "C-TAB") 'copilot-accept-completion)
  (setq copilot-lsp-settings '(:github (:copilot (:selectedCompletionModel "gpt-41-copilot"))))

  ;; (load "~/.emacs.d/lisp/init-gptel.el")

  ;; (use-package gptel-prompts
  ;;   :after (gptel)
  ;;   :demand t
  ;;   :config
  ;;   (custom-set-variables '(gptel-prompts-directory "~/code/AIPIHKAL/composable-prompts"))
  ;;   (gptel-prompts-update)
  ;;   ;; Ensure prompts are updated if prompt files change
  ;;   (gptel-prompts-add-update-watchers))

  ;; Use the system prompt builder function
  ;; (let ((build-directives-fun "~/code/AIPIHKAL/gptel-build-directives.el"))
  ;;   (when (f-exists-p build-directives-fun)
  ;;     (load build-directives-fun)
  ;;     ;; (custom-set-variables '(gptel-directives
  ;;     (setq gptel-directives (gjg/gptel-build-directives "~/code/AIPIHKAL/system-prompts/")
  ;;           gptel-system-message (alist-get 'default gptel-directives))))

  ;; (custom-set-variables '(gptel-directives (gjg/gptel-build-directives "~/projects/ai/AIPIHKAL/system-prompts/")))
  ;; (setq gptel-directives (gjg/gptel-build-directives "~/code/AIPIHKAL/system-prompts/"))

  ;; groovy
  (use-package groovy-mode
    :defer t
    :config (message "Loaded groovy mode"))
  (add-to-list 'auto-mode-alist '("Jenkinsfile$" . groovy-mode))

  (use-package vlf
    :ensure t
    :defer t
    :init
    (require 'vlf-setup))

  ;; Workaround for flycheck issue in golang
  ;; See https://github.com/flycheck/flycheck/issues/1523#issuecomment-469402280

  ;; (let ((govet (flycheck-checker-get 'go-vet 'command)))
  ;;   (when (equal (cadr govet) "tool")
  ;;     (setf (cdr govet) (cddr govet))))

  (setq neo-force-change-root nil)
  (setq neo-autorefresh t)

  ;; indent mode globally enabled (based on where your cursor is in the buffer)
  (indent-guide-global-mode)

  ;;(global-centered-cursor-mode t)
  (setq magit-repository-directories '("~/code/"))
                                        ;(global-git-commit-mode t)
  ;; (spacemacs/enable-transparency)
  (setq neo-theme 'icons)
  (setq powerline-default-separator 'arrow)
  (setq whitespace-style '(face trailing))

                                        ;(add-to-list 'load-path "~/.emacs.d/fci")
                                        ;(setq fci-rule-column 80)
                                        ;(setq-default fci-rule-column 80)
  (setq display-fill-column-indicator-column 80)
  (add-hook 'prog-mode-hook 'display-fill-column-indicator-mode)

  (add-hook 'csharp-mode-hook 'flycheck-mode)
  (eval-after-load
      'company
    '(add-to-list 'company-backends 'company-omnisharp))

  (add-hook 'csharp-mode-hook #'company-mode)
  (setq lsp-csharp-server-path "/usr/bin/omnisharp")
                                        ;(setq omnisharp-expected-server-version "1.35.0")
  )

;; Do not write anything past this comment. This is where Emacs will
;; auto-generate custom variable definitions.
(defun dotspacemacs/emacs-custom-settings ()
  "Emacs custom settings.
This is an auto-generated function, do not modify its content directly, use
Emacs customize menu instead.
This function is called at the very end of Spacemacs initialization."
  (custom-set-variables
   ;; custom-set-variables was added by Custom.
   ;; If you edit it by hand, you could mess it up, so be careful.
   ;; Your init file should contain only one such instance.
   ;; If there is more than one, they won't work right.
   '(custom-safe-themes
     '("67aa743fe5efbc86dec14d5e40fd570df16ad5453196c043c7806c182cdf2dbf"
       "d44cc29a46246fd81db53b97db761f1a773b81ff41c1a2f3e13db6baae4da969"
       "98b4ef49c451350c28a8c20c35c4d2def5d0b8e5abbc962da498c423598a1cdd" default))
   '(evil-want-Y-yank-to-eol nil)
   '(org-agenda-files '("~/TODO.org"))
   '(package-selected-packages
     '(ac-ispell ace-jump-helm-line ace-link afternoon-theme aggressive-indent aider
                 aidermacs alect-themes ample-theme ample-zen-theme ansible
                 ansible-doc anti-zenburn-theme apropospriate-theme auto-compile
                 auto-highlight-symbol auto-yasnippet badwolf-theme
                 birds-of-paradise-plus-theme blacken browse-at-remote
                 bubbleberry-theme bui busybee-theme cargo centered-cursor-mode
                 cherry-blossom-theme chocolate-theme clean-aindent-mode
                 clues-theme color-theme-sanityinc-solarized
                 color-theme-sanityinc-tomorrow column-enforce-mode
                 company-anaconda company-ansible company-go company-lsp
                 company-php company-phpactor company-tern company-web csv-mode
                 cyberpunk-theme cython-mode dactyl-mode dakrone-theme dap-mode
                 darkburn-theme darkmine-theme darkokai-theme darktooth-theme
                 define-word devdocs diminish dired-x django-theme docker
                 dockerfile-mode doom-themes dotenv-mode dracula-theme drupal-mode
                 dumb-jump editorconfig elisp-slime-nav ellama emmet-mode esh-help
                 eshell-prompt-extras eshell-z espresso-theme eval-sexp-fu
                 evil-anzu evil-args evil-cleverparens evil-ediff evil-escape
                 evil-exchange evil-goggles evil-iedit-state evil-indent-plus
                 evil-lion evil-lisp-state evil-magit evil-matchit evil-mc
                 evil-nerd-commenter evil-numbers evil-org evil-surround
                 evil-textobj-line evil-tutor evil-unimpaired
                 evil-visual-mark-mode evil-visualstar exotica-theme expand-region
                 eyebrowse eziam-theme fancy-battery farmhouse-theme
                 flatland-theme flatui-theme flx-ido flycheck-elsa
                 flycheck-package flycheck-pos-tip flycheck-rust font-lock+ fuzzy
                 gandalf-theme geben gh-md git-gutter-fringe+ git-link
                 git-messenger git-timemachine gitattributes-mode gitconfig-mode
                 gitignore-templates gnuplot go-autocomplete go-eldoc
                 go-fill-struct go-gen-test go-guru go-impl go-rename go-tag
                 godoctor golden-ratio google-translate gotham-theme gptel
                 grandshell-theme groovy-mode gruber-darker-theme gruvbox-theme
                 hc-zenburn-theme hcl-mode helm-ag helm-c-yasnippet helm-company
                 helm-css-scss helm-descbinds helm-flx helm-git-grep
                 helm-gitignore helm-ls-git helm-lsp helm-make helm-mode-manager
                 helm-org helm-org-rifle helm-projectile helm-purpose helm-pydoc
                 helm-spacemacs-faq helm-spacemacs-help helm-swoop helm-themes
                 helm-xref hemisu-theme heroku-theme highlight-indentation
                 highlight-numbers highlight-parentheses hl-todo hungry-delete
                 hybrid-mode ido-vertical-mode image-mode impatient-mode
                 importmagic indent-guide inkpot-theme ir-black-theme jazz-theme
                 jbeans-theme jinja2-mode js-doc js2-refactor json-navigator
                 kaolin-themes less-css-mode light-soap-theme link-hint
                 live-py-mode livid-mode llm lorem-ipsum lsp-docker lsp-mode
                 lsp-pyright lsp-python-ms lsp-treemacs lsp-ui lush-theme
                 macrostep madhat2r-theme magit-gitflow magit-section magit-svn
                 markdown-toc material-theme minimal-theme mmm-mode
                 modus-operandi-theme modus-vivendi-theme moe-theme molokai-theme
                 monochrome-theme monokai-theme move-text multi-term mustang-theme
                 mwim nameless naquadah-theme nginx-mode noctilux-theme
                 nodejs-repl nord-theme nvm ob obsidian-theme occidental-theme
                 oldlace-theme omtose-phellack-theme open-junk-file org-agenda
                 org-brain org-bullets org-cliplink org-download org-expiry
                 org-mime org-pomodoro org-present org-projectile
                 organic-green-theme orgit overseer paradox password-generator
                 pcre2el phoenix-dark-mono-theme phoenix-dark-pink-theme
                 php-auto-yasnippets php-extras phpcbf phpunit pip-requirements
                 pipenv pippel planet-theme plz plz-event-source plz-media-type
                 popwin powershell prettier-js professional-theme pug-mode
                 purple-haze-theme py-isort pyenv-mode pytest quelpa
                 quelpa-use-package racer railscasts-theme rainbow-delimiters
                 rebecca-theme restart-emacs reverse-theme sass-mode scss-mode
                 seti-theme shell-pop slim-mode smeargle smyx-theme
                 soft-charcoal-theme soft-morning-theme soft-stone-theme
                 solarized-theme soothe-theme spacegray-theme
                 spaceline-all-the-icons spaceline-config spacemacs-theme
                 string-inflection subatomic-theme subatomic256-theme
                 sublime-themes sunny-day-theme symbol-overlay symon tagedit
                 tango-2-theme tango-plus-theme tangotango-theme tao-theme
                 terminal-here terraform-mode tide toc-org toml-mode toxi-theme
                 tree-sitter tree-sitter-langs treemacs-evil treemacs-magit
                 treemacs-persp treemacs-projectile tsc twilight-anti-bright-theme
                 twilight-bright-theme twilight-theme ujelly-theme
                 underwater-theme unfill use-package uuidgen vi-tilde-fringe
                 vimrc-mode vlf vmd-mode volatile-highlights vterm wakatime-mode
                 web-beautify web-mode which-key white-sand-theme winum
                 writeroom-mode ws-butler xterm-color yaml-mode yapfify
                 yasnippet-snippets zen-and-art-theme zenburn-theme zoom-frm)))
  (custom-set-faces
   ;; custom-set-faces was added by Custom.
   ;; If you edit it by hand, you could mess it up, so be careful.
   ;; Your init file should contain only one such instance.
   ;; If there is more than one, they won't work right.
   )
  )
