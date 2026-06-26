# Pacman `provides`, renames, and binary ownership

Repo-specific triage note for package-manifest work (Story 2.2 and any future
package cleanup). Captures a gotcha that wasted several steps during the first
Story 2.2 inventory.

## The gotcha: `pacman -Qq <name>` matches `provides`, not just real packages

A query name can resolve through another package's `provides=` list, so a name
can look "installed" when **no package by that literal name exists** — a
different (often renamed/forked) package satisfies it.

Confirmed on this machine during Story 2.2:

| You query | Actually installed | Why |
| --- | --- | --- |
| `exa` | `eza` | eza is the maintained fork; declares `provides=exa` |
| `terraform` | `tenv-bin` | tenv (version manager) provides the `terraform` name |
| `networkmanager` | `networkmanager-iwd` | iwd-enabled NM build; provides/replaces `networkmanager` |
| `bind-tools` | `bind` | merged upstream |
| `crda` | `wireless-regdb` | crda retired |
| `mlocate` | `plocate` | plocate provides the `mlocate` compat name |
| `vi` | `ex-vi-compat` | provides `vi` |
| `vim` | `gvim` | gvim provides `vim` |

`pacman -Qq exa` exits 0, and `pacman -Qi exa` prints the **provider's** record
(`Name : eza`). So both `-Qq` and `-Qi` silently resolve the alias.

## Triage implication

When reconciling a manifest against live state, an old entry has **three** states,
not two — classify each one:

1. **SELF** — a package by that exact name is installed. Keep as-is.
2. **PROVIDED-BY `<pkg>`** — the literal package is gone but a renamed/forked/alt
   package provides the name. **Update the manifest to the real installed package
   name** (`exa`→`eza`, etc.), don't just delete it.
3. **ABSENT** — nothing provides it. Drop, or mark optional/fresh-machine-only.

Authoritative per-entry classifier (avoids the snapshot pitfalls below):

```bash
while IFS= read -r p; do [ -z "$p" ] && continue
  prov=$(pacman -Qi "$p" 2>/dev/null | awk -F': *' '/^Name/{print $2; exit}')
  if   [ -z "$prov" ];      then echo "ABSENT        $p"
  elif [ "$prov" = "$p" ];  then echo "SELF          $p"
  else                           echo "PROVIDED-BY   $p  ->  $prov"
  fi
done < .config/dotfiles/arch-packages/pacman
```

## How to find what package owns / provides a binary

- Installed file → owning package: `pacman -Qo /usr/bin/<binary>`
- Any repo file → package (needs `pacman -Fy` files DB once): `pacman -F <binary>`
- What a package provides: `pacman -Qi <pkg>` → `Provides` field, or
  `expac '%n: %S' <pkg>` (`%S` = provides).
- Is a name satisfied via provides? Compare `pacman -Qi <name>`'s resolved
  `Name:` against `<name>`.

Reminder: the real installed package *names* come from `pacman -Qq` (no argument)
— that list contains `eza`, never the `exa` alias. Membership tests against that
list are about **real packages**; per-name `-Qq <name>` tests are about
**provides satisfaction**. They answer different questions; don't mix them.

## Sandbox caveat observed during this work

In the agent sandbox, piping large command output to stdout via tools that use
`copy_file_range` (e.g. `cat file`, `expac … | sort` to the terminal) can fail
with `copy_file_range: bad file descriptor` or, worse, appear to truncate.
**Write to a file with a direct redirect and read the file** (`cmd > out.txt`,
then open it) instead of piping to stdout. Direct `>` redirects from `pacman`
were reliable; `cat`/pipe-to-terminal were not.

Also note: `pacman` is shell-aliased to `sudo pacman` in this repo's zsh. Query
ops (`-Q*`) need no root — call `/usr/bin/pacman -Q…` directly to skip the
password prompt.
