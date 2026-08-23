# polybar: `${env:...}` does not substitute inside module lists

**Seen:** 2026-08-23, Story 3.23 (#179), polybar 3.7 on the guest.

## Symptom

A `modules-right` mixing literal module names with env references —

```ini
modules-right = filesystem ${env:POLYBAR_SEG_TEMP:} time calendar
```

— renders no substitution. The literal string becomes a module name:

```
polybar|error: Disabling module "${env:POLYBAR_SEG_TEMP:}" (reason: Missing section "module/${env:POLYBAR_SEG_TEMP:}")
```

## Why

polybar's reference syntax (`${env:...}`, `${xrdb:...}`, `${colors....}`,
`${file:...}`) only resolves when the reference is the **entire value** of a
key. Inline mixing — references embedded in a longer value — is not
interpolation; the value is used verbatim. Module lists are split on spaces
*before* any reference handling, so each token is looked up as a section name.

## Consequences / what to do instead

- You cannot conditionally splice modules into a bar via env vars. Options
  that do work:
  - make the *whole* value one reference (`modules-right = ${env:LIST}`) and
    compose the entire list outside — moves theme layout into the launcher;
  - let hardware modules self-disable (internal/temperature with no thermal
    zone, internal/battery with no BAT*) and attach their powerline chevrons
    via `format-*-prefix` so the chrome dies with the module — chosen for
    3.23. The adjacency-dependent junction colors (only two, with the order
    preserved) come from a launcher-generated file spliced through a
    dedicated section's single `include-file` (`[hw]` +
    `~/.cache/polybar/hw-junctions`, `tools/hw-junctions`).
- Same whole-value rule bites `${colors.x}` inside format strings: inline
  `%{F#...}` tags need literal hex values, not palette references.

Related: [epic-3 Story 3.23](../../docs/epic-3-shell-editor-desktop-cleanup.md#story-323-hardware-segments-self-gate--tempbattery-vanish-where-the-hardware-doesnt-exist).
