# board-release (v2) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the `infra-release` skill to `board-release` and turn it multi-board: named profiles, per-profile scope/themes/language, draft-only Confluence publishing, and a legacy-config import.

**Architecture:** Same pure-procedural Claude Code skill (Markdown + HTML + shell). The change is to the **config model** (one flat config → a `profiles` map selected by argument) and to four procedure points in `SKILL.md` (selection, setup, scope-aware collection, draft-only publish). Reference/templates get placeholder/scope updates. No code runtime; the executor is Claude using the Atlassian MCP.

**Tech Stack:** Markdown, HTML (Confluence template), Bash (install.sh + verification), `python3` stdlib (html.parser), Atlassian MCP. Verification via `grep`, `bash -n`, `python3`, and a real symlink install.

## Global Constraints

Copied verbatim from `docs/SPEC.md`:

- Skill/command/repo renamed to **`board-release`**; invocation `/board-release <profile>`.
- Config: single per-user file `${XDG_CONFIG_HOME:-$HOME/.config}/board-release/config.yaml` with a
  `profiles` map + `defaultProfile`.
- Selection: no arg → 0=setup, 1=use it, many=use `defaultProfile` or ask.
- Per-profile **scope**: `done-now` | `date-window` | `sprint` (`current`|`last-closed`|`<name/id>`).
- `last-closed` is resolved by inspecting the `sprint` field on returned cards (MCP can't list sprints).
- Per-profile **themes** override the seed themes; output rendered in the profile's `outputLanguage`.
- Confluence: create as **draft**; **skill never auto-publishes** (gotcha: `updateConfluencePage`
  draft→current fails *"version must be 1 when publishing for the first time"*; no delete tool).
- Releases index = a page under the parent folder (API creates pages, not native folders).
- **Read-only on Jira** throughout; never post to Slack.
- Skill files in English; only the release output follows `outputLanguage`.

---

## File Structure

| File | Change |
|------|--------|
| `SKILL.md` | name→board-release; config schema→profiles; Setup (profile + legacy import); selection logic; scope-aware Phase 1; draft-only Phase 3 |
| `config.example.yaml` | flat → `profiles` map with `defaultProfile`, `scope`, `themes` |
| `install.sh` | `SKILL_NAME="board-release"` |
| `reference/jql-recipes.md` | add scope variants (done-now/date-window/sprint) |
| `reference/business-translation.md` | note: per-profile `themes` override seed themes |
| `reference/board-clear-runbook.md` | unchanged content (already placeholder-based) — no edit |
| `templates/confluence-release.html` | unchanged (markers already English) — no edit |
| `templates/slack-announcement.md` | unchanged — no edit |
| `README.md` | board-release naming, profiles, `/board-release <profile>` |
| `docs/SPEC.md` | already v2 (done) |
| `docs/PLAN.md` | this file |
| dir + symlink + GitHub remote | rename mechanics (Task 7) |

**Build order:** content edits first (SKILL/config/reference/README), then install.sh rename, then
the dir/symlink/remote rename last (so verification runs against the stable path until the final move).

---

### Task 1: Config schema → profiles (`config.example.yaml`)

**Files:**
- Modify: `/Users/taiar/dev/orn/infra-release-skill/config.example.yaml`

**Interfaces:**
- Produces: the canonical profiles config shape consumed by `SKILL.md` (Tasks 2-4): top-level
  `defaultProfile` + `profiles:` map; each profile has `cloudId, jiraBaseUrl, projectKey,
  doneStatusCategory, inProgressStatusCategory, nextStatusName, confluence{spaceId,parentId},
  releaseTitlePrefix, outputLanguage, scope{mode,window,sprint}, themes[]`.

- [ ] **Step 1: Replace the file contents**

```yaml
# Example config for the board-release skill.
# Copy to:  ${XDG_CONFIG_HOME:-$HOME/.config}/board-release/config.yaml
# (or let the skill generate it on first setup). Do NOT commit your real config.

defaultProfile: ""          # profile used when no argument is given and several profiles exist

profiles:
  example:
    cloudId: ""                          # Atlassian site (UUID). Discovered via getAccessibleAtlassianResources.
    jiraBaseUrl: ""                      # e.g. https://yoursite.atlassian.net
    projectKey: ""                       # e.g. OPS

    doneStatusCategory: "Done"           # status category of completed cards
    inProgressStatusCategory: "In Progress"
    nextStatusName: ""                   # the "coming up" status (e.g. "To Do" / "Ready"); empty = skip

    confluence:
      spaceId: ""                        # space where the page is created
      parentId: ""                       # parent folder or page (optional; empty = space root)

    releaseTitlePrefix: "Release Notes"  # final title gets " — YYYY-MM-DD" (or period/sprint)
    outputLanguage: "English"            # language of the release output (Confluence + Slack)

    scope:
      mode: done-now                     # done-now | date-window | sprint
      window: "-30d"                     # date-window only (or since/until)
      sprint: last-closed                # sprint only: current | last-closed | "<name or id>"

    themes: []                           # empty = generic seed themes; else list of {name, emoji, match: [...]}
```

- [ ] **Step 2: Verify shape**

Run:
```bash
cd /Users/taiar/dev/orn/infra-release-skill
for s in "defaultProfile:" "profiles:" "scope:" "mode: done-now" "themes: \[\]" "board-release"; do
  grep -qE "$s" config.example.yaml && echo "OK: $s" || echo "MISSING: $s"
done
python3 -c "import yaml,sys" 2>/dev/null && python3 -c "import yaml; d=yaml.safe_load(open('config.example.yaml')); assert 'profiles' in d and 'defaultProfile' in d; print('YAML OK')" || echo "yaml module absent — skip parse (grep is sufficient)"
```
Expected: 6 `OK:` lines; `YAML OK` if pyyaml present, otherwise the skip note.

- [ ] **Step 3: Commit**

```bash
cd /Users/taiar/dev/orn/infra-release-skill
git add config.example.yaml
git commit -m "feat: config schema → named profiles (defaultProfile + profiles map)"
```

---

### Task 2: JQL recipes → scope variants (`reference/jql-recipes.md`)

**Files:**
- Modify: `/Users/taiar/dev/orn/infra-release-skill/reference/jql-recipes.md`

**Interfaces:**
- Consumes: profile fields `projectKey`, `nextStatusName`, `scope`.
- Produces: a `COMPLETED` query per scope mode + the `last-closed` resolution recipe, referenced by
  `SKILL.md` Phase 1.

- [ ] **Step 1: Replace the "Queries" section** so COMPLETED branches by scope. Set the file to:

````markdown
# JQL recipes — collection (Phase 1)

Replace `{{PROJECT_KEY}}` and `{{NEXT_STATUS}}` with profile values (`projectKey`, `nextStatusName`).
Use the profile's `cloudId` on every call.

> **Always filter by status category, not by name.** On localized sites, searching by a translated
> status name (e.g. `status = "Em andamento"`) can return empty. `statusCategory` is stable.

## COMPLETED — depends on the profile's `scope.mode`

**`done-now`:**
```
project = {{PROJECT_KEY}} AND statusCategory = Done ORDER BY resolutiondate DESC
```

**`date-window`** (`scope.window`, e.g. `-30d`, or `since`/`until`):
```
project = {{PROJECT_KEY}} AND statusCategory = Done AND resolutiondate >= {{WINDOW}} ORDER BY resolutiondate DESC
```

**`sprint`:**
- `current` → `project = {{PROJECT_KEY}} AND statusCategory = Done AND sprint in openSprints()`
- `"<name or id>"` → `project = {{PROJECT_KEY}} AND statusCategory = Done AND sprint = "{{SPRINT}}"`
- `last-closed` → run `project = {{PROJECT_KEY}} AND statusCategory = Done AND sprint in closedSprints() ORDER BY resolutiondate DESC`,
  then read the `sprint` field on the returned cards, pick the sprint with the most recent
  `completeDate`, and keep only that sprint's cards. If ambiguous, list candidate sprints and ask.
  (The MCP can't list Agile sprints, so this is resolved from the returned data. Request `customfield`
  sprint via `fields: ["*all"]` on a small page, or include the sprint field name if known.)

## ROADMAP — scope-independent (always current state)

**IN_PROGRESS:**
```
project = {{PROJECT_KEY}} AND statusCategory = "In Progress" ORDER BY updated DESC
```
**SELECTED** (only if `nextStatusName` set):
```
project = {{PROJECT_KEY}} AND status = "{{NEXT_STATUS}}" ORDER BY updated DESC
```

## Fields to request

`["key","summary","description","issuetype","labels","components","assignee","resolutiondate","parent","updated"]`
(For `sprint` scope add the sprint field, or fetch `*all` on a small page to find it.)
Markdown body: pass `responseContentFormat: "markdown"`.

## Pagination + extraction

1. Call `searchJiraIssuesUsingJql` with `maxResults: 100`.
2. If the response exceeds the tool's token limit, it is saved to a file — read it with `jq`.
3. Repeat with `nextPageToken` until `pageInfo.hasNextPage = false`.

```bash
jq -r '.issues.nodes[] | "\(.key)\t\(.fields.issuetype.name)\t\(.fields.summary)"' "$F"
jq -r '.issues.nodes[] | "\(.key)\t\(.fields.labels | join(","))"' "$F"
jq -r '.issues.nodes[] | .fields.status.statusCategory.name' "$F" | sort | uniq -c
```

## Counting

Use `computeIssueCount: true` with `maxResults: 1` on a count-only query.
````

- [ ] **Step 2: Verify**

Run:
```bash
cd /Users/taiar/dev/orn/infra-release-skill
for s in "done-now" "date-window" "{{WINDOW}}" "openSprints()" "closedSprints()" "completeDate" "scope-independent"; do
  grep -qF "$s" reference/jql-recipes.md && echo "OK: $s" || echo "MISSING: $s"
done
```
Expected: 7 `OK:` lines.

- [ ] **Step 3: Commit**

```bash
cd /Users/taiar/dev/orn/infra-release-skill
git add reference/jql-recipes.md
git commit -m "feat: JQL recipes branch by scope (done-now/date-window/sprint)"
```

---

### Task 3: Themes note (`reference/business-translation.md`)

**Files:**
- Modify: `/Users/taiar/dev/orn/infra-release-skill/reference/business-translation.md`

**Interfaces:**
- Consumes: profile `themes`.
- Produces: the rule that per-profile `themes` override the seed themes (referenced by SKILL.md Phase 2).

- [ ] **Step 1: Replace the "Seed themes" heading paragraph.** Find:

```markdown
## Seed themes (adjust per board)
```
Replace that line with:
```markdown
## Seed themes (fallback)

If the active profile defines a `themes` list, use it (each `{name, emoji, match:[labels/keywords]}`;
`match` is a hint, not a strict regex). Otherwise fall back to the seed themes below.
```

- [ ] **Step 2: Verify**

Run:
```bash
cd /Users/taiar/dev/orn/infra-release-skill
grep -qF "Seed themes (fallback)" reference/business-translation.md && echo "OK: fallback heading"
grep -qF "profile defines a \`themes\` list" reference/business-translation.md && echo "OK: override rule"
```
Expected: 2 `OK:` lines.

- [ ] **Step 3: Commit**

```bash
cd /Users/taiar/dev/orn/infra-release-skill
git add reference/business-translation.md
git commit -m "docs: per-profile themes override the seed themes"
```

---

### Task 4: SKILL.md — name, profiles, selection, setup, scope, draft-only

**Files:**
- Modify: `/Users/taiar/dev/orn/infra-release-skill/SKILL.md`

**Interfaces:**
- Consumes: `config.example.yaml` shape (Task 1), scope recipes (Task 2), themes rule (Task 3).
- Produces: the invocable `/board-release <profile>` skill (frontmatter `name: board-release`).

- [ ] **Step 1: Replace the whole file** with:

````markdown
---
name: board-release
description: Use when closing out a Jira board in release cycles — generates a stakeholder release page in Confluence (as a draft) from completed cards, a roadmap of in-progress/selected work, and a Slack announcement to post manually. Multi-board via named profiles; read-only on Jira; interactive first-time setup.
---

# board-release

Closes a Jira board in release cycles: a **stakeholder** release (not a tech report), a roadmap of
what's coming, and a ready-to-post Slack announcement. Supports **multiple boards** via named profiles.

**Guarantees:** Read-only on Jira (never transitions/archives/edits). Confluence created as a
**draft** — the skill **never auto-publishes**. Slack is **never** posted automatically.

## Config (per user, outside the repo)

File: `${XDG_CONFIG_HOME:-$HOME/.config}/board-release/config.yaml`. Format in `config.example.yaml`:
a top-level `defaultProfile` plus a `profiles:` map. Each profile is self-contained:
`cloudId, jiraBaseUrl, projectKey, doneStatusCategory, inProgressStatusCategory, nextStatusName,
confluence{spaceId,parentId}, releaseTitlePrefix, outputLanguage, scope{mode,window,sprint}, themes[]`.

## Selecting a profile

Invoked as `/board-release <profile>`. Read the config, then:
- arg given → use that profile (if missing, offer to create it via Setup).
- no arg + 0 profiles → run **Setup**.
- no arg + 1 profile → use it.
- no arg + many → use `defaultProfile` if set, else list the profiles and ask which.

## Setup phase (create/edit one profile)

Run when creating a new profile or when required fields are missing
(`cloudId`, `projectKey`, `confluence.spaceId`, `outputLanguage`).

0. **Legacy import:** if `~/.config/infra-release/config.yaml` exists, offer to import it as a
   profile (default name `infra`) instead of asking everything again.
1. **Profile name.**
2. **Atlassian site:** `getAccessibleAtlassianResources` → pick → `cloudId` + `jiraBaseUrl` (the `url`).
3. **Board:** `getVisibleJiraProjects` (or ask) → `projectKey`.
4. **Status mapping:** confirm done/in-progress categories; for "coming up", list statuses
   (`getTransitionsForJiraIssue` on a sample card, `includeUnavailableTransitions: true`) → `nextStatusName`.
5. **Scope:** pick `done-now` / `date-window` (+ `window`) / `sprint` (+ `current`/`last-closed`/name).
6. **Confluence:** `getConfluenceSpaces` → `spaceId`; ask `parentId`.
7. **Title & language:** `releaseTitlePrefix`, `outputLanguage`.
8. **Themes:** use generic defaults, or define custom (skippable; editable later).
9. Write the profile into `config.yaml` (`mkdir -p` the dir) and show a summary.

Reconfigure = edit `config.yaml`, or ask to "redo setup" for a profile.

## Procedure (5 phases, with checkpoints ✋)

All `{...}` values come from the selected profile. **Write every human-facing string in the
generated release — section headings included — in `{outputLanguage}`, with correct orthography and
diacritics (never strip accents).**

### Phase 0 — Scope ✋
Count the completed cards for the profile's scope (`computeIssueCount`) and confirm: "close the
completed cards in `{projectKey}` ({scope.mode}) now?". Only proceed with the OK.

### Phase 1 — Collect (read-only)
Run the queries in `reference/jql-recipes.md`. The COMPLETED query branches on `scope.mode`
(`done-now` / `date-window` with `{window}` / `sprint` with `current`/`last-closed`/name — for
`last-closed`, isolate the most recently completed sprint from the returned cards' `sprint` field).
The roadmap (IN_PROGRESS + SELECTED) is scope-independent. Paginate; extract with `jq`. Filter by
`statusCategory`, never by a localized status name.

### Phase 2 — Synthesize
Apply `reference/business-translation.md` using the profile's `themes` (fall back to seed themes if
empty). Write the TL;DR + per-theme paragraphs (non-technical, quantified) + roadmap, in `{outputLanguage}`.
Cards you can't confidently theme go to a "Review" note.

### Phase 3 — Confluence (draft only) ✋
Fill `templates/confluence-release.html` (marker `{{RELEASE_TITLE}}` = `{releaseTitlePrefix}`),
translating headings into `{outputLanguage}`. Create the page with `createConfluencePage`:
`spaceId = {confluence.spaceId}`, `parentId = {confluence.parentId}` (omit if empty),
`contentFormat: html`, **`status: draft`**, title `"{releaseTitlePrefix} — {PERIOD}"` (PERIOD =
date for done-now, the window for date-window, the sprint name for sprint).
**Do NOT auto-publish:** present the draft link and tell the user to review and click **Publish** in
the Confluence UI. (`updateConfluencePage` draft→current fails with *"version must be 1…"* and there
is no delete tool, so any auto-publish leaves an orphan draft.)
**Idempotency:** before creating, look for a page with the same title under the parent; if found,
`updateConfluencePage` its draft content instead of duplicating.
**Releases index:** if `parentId` is a folder, nest releases under a "Releases" index page inside it
(create the index once; the API makes pages, not native folders).

### Phase 4 — Slack (manual) ✋
Fill `templates/slack-announcement.md` (labels in `{outputLanguage}`) and present the result **inside
a code block** for the user to copy. **Do not post.**

### Phase 5 — Guided cleanup ✋
Deliver `reference/board-clear-runbook.md` (substituting `{projectKey}` and `{jiraBaseUrl}`): plan
check + path A/B + re-access. The skill does **not** transition or archive anything.

## Safety rails
- NEVER transition/edit/archive an issue on Jira.
- NEVER post to Slack.
- NEVER auto-publish Confluence — create the draft and stop.
````

- [ ] **Step 2: Verify frontmatter, selection, setup, scope, draft-only**

Run:
```bash
cd /Users/taiar/dev/orn/infra-release-skill
grep -q '^name: board-release' SKILL.md && echo "OK: name"
for s in "Selecting a profile" "defaultProfile" "Legacy import" "scope.mode" "done-now" "last-closed" "never auto-publish" "status: draft" "Phase 0" "Phase 5" "Read-only on Jira"; do
  grep -qF "$s" SKILL.md && echo "OK: $s" || echo "MISSING: $s"
done
echo "-- no stale name --"
grep -q 'name: infra-release' SKILL.md && echo "STALE: infra-release name present" || echo "OK: no infra-release frontmatter"
```
Expected: `OK: name`, 11 `OK:` lines, and `OK: no infra-release frontmatter`.

- [ ] **Step 3: Verify referenced files exist**

Run:
```bash
cd /Users/taiar/dev/orn/infra-release-skill
for f in reference/jql-recipes.md reference/business-translation.md reference/board-clear-runbook.md templates/confluence-release.html templates/slack-announcement.md; do
  grep -qF "$f" SKILL.md && test -f "$f" && echo "OK: $f" || echo "PROBLEM: $f"
done
```
Expected: 5 `OK:` lines.

- [ ] **Step 4: Commit**

```bash
cd /Users/taiar/dev/orn/infra-release-skill
git add SKILL.md
git commit -m "feat: SKILL.md v2 — board-release, profiles, selection, scope, draft-only"
```

---

### Task 5: README → board-release + profiles

**Files:**
- Modify: `/Users/taiar/dev/orn/infra-release-skill/README.md`

**Interfaces:**
- Consumes: nothing.
- Produces: user-facing docs matching the renamed, multi-board skill.

- [ ] **Step 1: Replace the file** with:

````markdown
# board-release-skill

A Claude Code skill that **closes a Jira board in release cycles** and produces a
**stakeholder release** in Confluence (as a draft), a **roadmap** of what's coming, and a
ready-to-post **Slack announcement** — without going card by card.

Works with **multiple boards** via named **profiles**. On the first run for a board, an interactive
setup discovers the Atlassian site and asks for the board, statuses, scope, Confluence space,
language, and themes; everything is stored per user. Nothing about a board is baked into the skill.

## What it does

1. Reads the board's **completed** cards for the profile's scope (read-only, via the Atlassian MCP).
2. Translates the technical work into **business impact**, grouped by the profile's themes.
3. Creates a **release page** in Confluence as a **draft** — you review and publish in the UI.
4. Generates a **Slack announcement** (mrkdwn) for you to post manually.
5. Hands you a **guided cleanup runbook** for the board + how to **re-access** the cards later.

The release output (Confluence + Slack) is written in each profile's **language**; the skill files
are in English.

## Guarantees

- **Read-only on Jira:** never transitions, archives, or edits issues.
- **Draft only:** the page is created as a draft; the skill never auto-publishes.
- **Slack manual:** the skill never posts on its own.

## Install

```bash
./install.sh
```
Creates a symlink at `~/.claude/skills/board-release`. Restart your Claude Code session.

## Usage

```
/board-release <profile>
```
With no argument: 0 profiles → setup; 1 → that profile; many → the default or it asks.
The config lives at `${XDG_CONFIG_HOME:-$HOME/.config}/board-release/config.yaml`
(see `config.example.yaml`).

## Layout

- `SKILL.md` — procedure + setup + config schema
- `config.example.yaml` — profiles config format
- `reference/` — JQL recipes (scope variants), translation guide, cleanup runbook
- `templates/` — Confluence page HTML, Slack mrkdwn
- `docs/` — SPEC and PLAN
````

- [ ] **Step 2: Verify**

Run:
```bash
cd /Users/taiar/dev/orn/infra-release-skill
for s in "board-release-skill" "/board-release <profile>" "profiles" "Draft only" "~/.config/board-release/"; do
  grep -qF "$s" README.md && echo "OK: $s" || echo "MISSING: $s"
done
grep -q 'infra-release' README.md && echo "STALE: infra-release in README" || echo "OK: no infra-release in README"
```
Expected: 5 `OK:` lines + `OK: no infra-release in README`.

- [ ] **Step 3: Commit**

```bash
cd /Users/taiar/dev/orn/infra-release-skill
git add README.md
git commit -m "docs: README → board-release, profiles, draft-only"
```

---

### Task 6: install.sh → board-release

**Files:**
- Modify: `/Users/taiar/dev/orn/infra-release-skill/install.sh:5`

**Interfaces:**
- Consumes: `SKILL.md` with `name:`.
- Produces: symlink `~/.claude/skills/board-release` → repo.

- [ ] **Step 1: Change the skill name**

In `install.sh`, replace the line:
```bash
SKILL_NAME="infra-release"
```
with:
```bash
SKILL_NAME="board-release"
```

- [ ] **Step 2: Syntax + dry verify**

Run:
```bash
cd /Users/taiar/dev/orn/infra-release-skill
bash -n install.sh && echo "SYNTAX OK"
grep -q 'SKILL_NAME="board-release"' install.sh && echo "OK: name set"
grep -q 'infra-release' install.sh && echo "STALE" || echo "OK: no infra-release in install.sh"
```
Expected: `SYNTAX OK`, `OK: name set`, `OK: no infra-release in install.sh`.

- [ ] **Step 3: Commit**

```bash
cd /Users/taiar/dev/orn/infra-release-skill
git add install.sh
git commit -m "chore: install.sh uses board-release skill name"
```

---

### Task 7: Rename dir + symlink + remote, then smoke-test install

**Files:**
- Move: `/Users/taiar/dev/orn/infra-release-skill` → `/Users/taiar/dev/orn/board-release-skill`
- Remove: symlink `~/.claude/skills/infra-release`

**Interfaces:**
- Consumes: Tasks 1-6 committed.
- Produces: the skill discoverable as `board-release` from the renamed repo.

- [ ] **Step 1: Move the repo directory**

Run:
```bash
mv /Users/taiar/dev/orn/infra-release-skill /Users/taiar/dev/orn/board-release-skill
cd /Users/taiar/dev/orn/board-release-skill && git status --short && echo "MOVED OK"
```
Expected: clean status + `MOVED OK`.

- [ ] **Step 2: Remove the old symlink and install fresh**

Run:
```bash
rm -f "${HOME}/.claude/skills/infra-release"
cd /Users/taiar/dev/orn/board-release-skill
./install.sh
ls -l "${HOME}/.claude/skills/board-release"
test -f "${HOME}/.claude/skills/board-release/SKILL.md" && echo "SKILL.md reachable"
```
Expected: symlink `board-release` → `/Users/taiar/dev/orn/board-release-skill` + `SKILL.md reachable`.

- [ ] **Step 3: Idempotent re-run**

Run: `cd /Users/taiar/dev/orn/board-release-skill && ./install.sh && echo "RERUN OK"`
Expected: `Symlink updated…` + `RERUN OK`.

- [ ] **Step 4: Update the git remote (GitHub repo renamed by the user in the UI)**

Run:
```bash
cd /Users/taiar/dev/orn/board-release-skill
git remote set-url origin git@ornitorrinco:orntrrncmcnha/board-release-skill.git
git remote -v
```
Expected: origin points at `board-release-skill.git`.
(If the user hasn't renamed the GitHub repo yet, skip this step and tell them to rename it, then run it.)

- [ ] **Step 5: Commit the doc/plan move (paths only; content unchanged)**

```bash
cd /Users/taiar/dev/orn/board-release-skill
git add -A
git commit -m "chore: rename repo to board-release-skill" --allow-empty
```

---

## Final verification (after all tasks)

- [ ] **No stale name anywhere in tracked files**

Run (exclude `docs/`, which legitimately documents the rename + legacy import):
```bash
cd /Users/taiar/dev/orn/board-release-skill
grep -rn 'infra-release' . --exclude-dir=.git --exclude-dir=docs | grep -v 'config.yaml' || echo ">>> CLEAN: no infra-release references <<<"
```
Expected: `>>> CLEAN <<<`. Acceptable mentions that this grep deliberately skips: the legacy-import
path `~/.config/infra-release/config.yaml` in SKILL.md (intentional), and the historical
references inside `docs/SPEC.md` and `docs/PLAN.md` (they document the v1→v2 rename and the
legacy-import feature). Everything else must be gone.

- [ ] **No board-specifics**

Run:
```bash
cd /Users/taiar/dev/orn/board-release-skill
grep -rinE 'paag|ef9db663|23757135|108658705|paag-tech|Comply|FinOps|Selected for Development' . --exclude-dir=.git || echo ">>> CLEAN <<<"
```
Expected: `>>> CLEAN <<<`.

- [ ] **Skill discoverable**: `board-release` appears in the skills list (symlink live, `name:` valid).

- [ ] **E2E acceptance** (manual, outside the plan): `/board-release` with no arg → import the legacy
  `infra` profile → run a closing → draft created; then add a `data` profile and run it.

---

## Self-Review (by the plan author)

**Spec coverage:**
- §2 rename → Tasks 4,5,6,7. ✅
- §3 config/profiles model → Task 1; consumed in Task 4. ✅
- §4 selection & setup (+ legacy import) → Task 4. ✅
- §5 collection by scope (done-now/date-window/sprint/last-closed) → Task 2; wired in Task 4 Phase 1. ✅
- §6 themes override → Task 3; wired in Task 4 Phase 2. ✅
- §7 Confluence draft-only + index + idempotency → Task 4 Phase 3. ✅
- §8 Slack + cleanup → Task 4 Phases 4-5 (templates/runbook already placeholder-based; no edit). ✅
- §9 constraints → encoded in Tasks 2 & 4 prose. ✅
- §10 rename/migration mechanics → Task 7 (dir/symlink/remote) + Task 4 step 0 (legacy import). ✅
- §12 acceptance criteria → Final verification + E2E. ✅

**Placeholder scan:** `{{...}}` / `{...}` / `{PERIOD}` are runtime markers (by design), not plan
placeholders. No "TBD/TODO". ✅

**Type/name consistency:** profile field names identical across Tasks 1, 2, 4 (`scope.mode`,
`scope.window`, `scope.sprint`, `themes`, `defaultProfile`, `confluence.spaceId/parentId`);
`name: board-release` consistent across SKILL.md/install.sh/symlink/README. Template markers
unchanged (already English) so Tasks reference existing names. ✅
