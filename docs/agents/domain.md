# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring
the codebase. This repo is **single-context**: one primary glossary at the root, no
`CONTEXT-MAP.md`.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root — the primary glossary. Ubiquitous language for the
  workstation platform: the reconcile loop, the update loop, quarantine, and the
  AUR-safety model.
- **`docs/CONTEXT.md`** — a sub-glossary scoped to the vm-harness / bootstrap tooling
  (phase, run, attached/detached, state logs, gold run). It lives under `docs/` rather
  than the root on purpose: the repo root maps into `$HOME` via yadm, so root files are
  expensive. Read it when the topic is the harness or the install path.
- **Decision records**, in two places:
  - `docs/adr/` — where new ADRs go, numbered `NNNN-slug.md`.
  - `docs/decision-*.md` — the existing flat decision records, which predate `docs/adr/`
    and are ADRs in everything but location. They carry Status, Supersedes, Executed-by,
    and issue links. Read them; do not renumber or move them.

Today that means `docs/decision-bootstrap-architecture.md`,
`docs/decision-daily-driver-vm.md`, and `docs/decision-metal-rehearsal.md`.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't
suggest creating them upfront. The `domain-modeling` skill (reached via `grill-with-docs`
and `improve-codebase-architecture`) creates them lazily when terms or decisions actually
get resolved.

## File structure

```text
/
├── CONTEXT.md              ← primary glossary (workstation platform)
├── docs/
│   ├── CONTEXT.md          ← sub-glossary (vm-harness / bootstrap)
│   ├── adr/                ← new ADRs, numbered
│   └── decision-*.md       ← existing decision records, still current
└── knowledge/              ← reusable recipes, references, error patterns
```

`knowledge/` is not a domain doc. It holds repeatable how-to material under Hard rule 7 in
`CLAUDE.md`: `knowledge/reference/` for repo facts and conventions, `knowledge/errors/`
for failure patterns, `knowledge/recipes/` for step-by-step workflows, and
`knowledge/examples/` for concrete examples. Consult it before re-deriving a workflow.

## Use the glossary's vocabulary

When your output names a domain concept (an issue title, a refactor proposal, a
hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms
the glossary explicitly avoids — it names them: say "reconcile loop", not "sync" or
"install flow"; say "update loop", not "upgrade flow" or "maintenance script".

If the concept you need isn't in the glossary yet, that's a signal: either you're
inventing language the project doesn't use (reconsider) or there's a real gap (note it for
`domain-modeling`).

## Flag decision conflicts

If your output contradicts an existing ADR or `docs/decision-*.md`, surface it explicitly
rather than silently overriding:

> _Contradicts the bootstrap-architecture decision (Story 2.5, #27), but worth reopening
> because…_
