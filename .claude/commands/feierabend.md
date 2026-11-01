---
name: feierabend
description: Wrap up the session cleanly. Review the working state, align format and docs, run the tests, write memory and the handoff for the next session.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

### Goal

Wrap up the session in as few steps as possible. Afterwards, docs, memory and spec match the current state, and `.claude/handoff.md` carries it into the next session.

You may read, check and summarize on your own. **Before writing files or committing, show what and why, and wait for confirmation.** Exception: `.claude/handoff.md` is written without asking.

There are no issues and no CI. Open items live in the handoff and, if they belong to a spec, in its “Open points” section.

### Steps

#### 1. Situation, one call

```bash
git status --short; git log --oneline -10; git log -10 --format=%B | grep -inE "co-authored-by|generated with|noreply@anthropic"
```

- Summarize in 3–6 bullet points what the session changed and which decisions were made, with their reasons.
- Uncommitted changes: propose topically grouped commits with an English message and commit only after confirmation. No attribution, no reference to Claude.
- If the `grep` line matches anything, report the commit.

#### 2. Check what the session touched

Only for changed areas, skip otherwise:

- **Swift (`app/`):** `swift test` and `swift format lint --recursive Sources Tests` in `app/`. For changes to the bundle, `Info.plist` or `build.sh`, also `./build.sh`. Report the result, do not format yourself.
- **Python:** `python3 -m py_compile nuimo.py bridge.py`.
- **Language:** everything in the repository is English. Report German text in changed files.
- **TODO, FIXME, HACK** in changed files: list them and carry them into the handoff.

#### 3. Align format and docs

`docs/config.md` is the binding description of the mapping. If the session changed events, actions or settings, these places must match:

- `docs/config.md`
- `app/Resources/default-config.toml`
- `config.toml` and `bridge.py` if the bridge knows the setting too, otherwise the table “Differences from bridge.py”
- `CHANGELOG.md` under `[Unreleased]`

Also:

- **Spec:** bring the status and acceptance checklist of the affected spec under `docs/specs/` up to date. Tick off finished items, enter resolved open items with their outcome.
- **README:** new knowledge about the device goes into “Nuimo quirks”. Changed commands for building and running as well.
- **CLAUDE.md:** only lasting rules. State and next steps belong in the handoff.

For mismatches, say which side is probably newer and ask which one applies. Show planned changes, then write.

#### 4. Memory

`MEMORY.md` is already in context, the path is in the system prompt. Open only the files that change.

- Bring the project status in `nuimo-project-status.md` up to date.
- Add only what is not in code, Git, README, specs or `CLAUDE.md`, for example feedback on the way of working or discarded approaches with the reason.
- Correct outdated entries, delete wrong ones, turn relative dates into absolute ones.

#### 5. Processes

The Nuimo allows only one connection. List running `bridge.py`, `nuimo.py` or a launched `NuimoBar.app` and offer to quit them:

```bash
pgrep -fl "bridge.py|nuimo.py|NuimoBar"
```

#### 6. Handoff

Overwrite `.claude/handoff.md` and show its content to the user:

```markdown
# Session handoff [YYYY-MM-DD]

## Done
## Open
## Next steps (concrete, where to continue)
## Changes to docs and memory
## Status (commits, tests, running processes)
```

The file is not committed. The next session reads it at the start, as stated in `CLAUDE.md`.

### Rules

- **Do not commit or push without confirmation.**
- **No formatters with autofix.** Only check and report.
- **No subagent.**
- **German** in the conversation with the user, **English** in the repository.
- **Markdown:** one paragraph or list item per line.
- **No reference to Claude or AI** in commit messages, specs or reference docs. The origin story in the README is intentional.

$ARGUMENTS

---
*v1.2 — 2026-10-31 — English, for the public repository. Matthias Siedler*
