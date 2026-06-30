# SPEC — board-release (v2, multi-board)

**Status:** design approved (awaiting spec review)
**Repository:** standalone git repo (a publishable Claude Code skill). Renamed from `infra-release`.

---

## 1. Problem

A team runs several Jira boards of different kinds (infra, data, product…). For each, periodically,
we want to:

1. Know, as an admin, **what to do so finished cards disappear** from the board.
2. Know **how to re-access** those cards afterward.
3. Produce a **stakeholder release text** of completed work — for the **company**, not the eng team,
   without going card by card.
4. Give an **overview of what's in progress and selected for delivery**.

v1 (`infra-release`) did this for a single board via one flat config. v2 generalizes to **many
boards** via **named profiles**, each with its own board, statuses, Confluence target, language,
**closing scope**, and **themes** — selected by argument.

## 2. Design decisions

| # | Decision | Choice |
|---|----------|--------|
| Name | Skill/command/repo | **Renamed to `board-release`** (`/board-release <profile>`) |
| Multi-board | How several boards coexist | **Named profiles** in a single per-user config |
| Selection | Which profile runs | `<profile>` arg; no arg → 0=setup, 1=use it, many=ask (or `defaultProfile`) |
| Closing scope | What a closing covers | **Per profile**: `done-now` / `date-window` / `sprint` |
| Themes | Grouping vocabulary | **Per profile** (`themes` overrides the generic seed themes) |
| Confluence publish | Draft vs live | **Create as draft; user publishes in the UI.** Skill never auto-publishes |
| Output language | Release language | Per profile (`outputLanguage`); skill files stay English |
| Board cleanup | Disappear from board | **Guided manual cleanup** — skill read-only on Jira |
| Build approach | | Pure procedural skill (unchanged) |

## 3. Config model

Single per-user file: `${XDG_CONFIG_HOME:-$HOME/.config}/board-release/config.yaml`.

```yaml
defaultProfile: infra        # used when no arg is given and several profiles exist
profiles:
  infra:
    cloudId: "..."
    jiraBaseUrl: "https://yoursite.atlassian.net"
    projectKey: "INFRA"
    doneStatusCategory: "Done"
    inProgressStatusCategory: "In Progress"
    nextStatusName: "To Do"        # the "coming up" status; empty = skip the "coming up" section
    confluence:
      spaceId: "..."
      parentId: "..."        # parent page/folder; empty = space root
    releaseTitlePrefix: "Release Notes"
    outputLanguage: "English"
    scope:
      mode: done-now         # done-now | date-window | sprint
      window: "-30d"         # for date-window (or since/until)
      sprint: last-closed    # for sprint: current | last-closed | "<name or id>"
    themes: []               # empty = generic seed themes; else list of {name, emoji, match:[...]}
  data:
    projectKey: "DATA"
    # ...same fields...
    scope: { mode: sprint, sprint: last-closed }
    themes:
      - { name: "Data quality", emoji: "✅", match: ["data-quality","dq"] }
      - { name: "Pipelines & ingestion", emoji: "🔄", match: ["pipeline","ingestion","etl"] }
      - { name: "Data products & datasets", emoji: "📦", match: ["dataset","data-product"] }
      - { name: "Governance", emoji: "🔒", match: ["governance","catalog","privacy"] }
```

Each profile is self-contained. The skill stores nothing about any board in its own files.

## 4. Selection & setup

**Selection:** `/board-release <profile>`.
- No arg + 0 profiles → run **setup** (create the first profile).
- No arg + 1 profile → use it.
- No arg + many → use `defaultProfile`, or list and ask.
- Arg names a missing profile → offer to create it.

**Setup (creates/edits one profile):**
1. Ask the **profile name**.
2. **Atlassian site:** `getAccessibleAtlassianResources` → pick → `cloudId` + `jiraBaseUrl`.
3. **Board:** `getVisibleJiraProjects` (or ask) → `projectKey`.
4. **Status mapping:** confirm done/in-progress categories; for "coming up", list statuses
   (`getTransitionsForJiraIssue` on a sample card, `includeUnavailableTransitions: true`) → `nextStatusName`.
5. **Scope:** pick `done-now` / `date-window` (+ window) / `sprint` (+ which sprint).
6. **Confluence:** `getConfluenceSpaces` → `spaceId`; ask `parentId`.
7. **Title & language:** `releaseTitlePrefix`, `outputLanguage`.
8. **Themes:** use generic defaults, or define custom (skippable; editable later).
9. Write the profile into `config.yaml` (`mkdir -p` the dir) and show a summary.

**Legacy import:** if `~/.config/infra-release/config.yaml` exists, offer to import it as a profile
(default name `infra`) instead of reconfiguring from scratch.

## 5. Collection by scope (Phase 1)

Completed-cards query depends on `scope.mode` (always also filter `project = {projectKey}`):

- **`done-now`** → `statusCategory = Done`.
- **`date-window`** → `statusCategory = Done AND resolutiondate >= {window}` (or `resolutiondate >= "{since}" AND resolutiondate <= "{until}"`).
- **`sprint`**:
  - `current` → `statusCategory = Done AND sprint in openSprints()`.
  - `last-closed` → query `statusCategory = Done AND sprint in closedSprints()`, read the `sprint`
    field on the returned cards, pick the sprint with the most recent `completeDate`, and keep only
    its cards. If ambiguous, show candidate sprints and ask.
  - `"<name or id>"` → `statusCategory = Done AND sprint = "<...>"`.

In-progress and "coming up" queries are **scope-independent** (always current state), per
`reference/jql-recipes.md`. Filter by `statusCategory`, never by a localized status name.

## 6. Themes (Phase 2)

- If `profile.themes` is non-empty, use it; else use the seed themes in
  `reference/business-translation.md`.
- Each theme: `{ name, emoji, match: [labels/keywords] }`. `match` guides grouping; it is a hint,
  not a strict regex — prose is still written with judgment.
- All human-facing strings (headings included) rendered in `outputLanguage`, correct diacritics.

## 7. Confluence publish (Phase 3) — draft + manual publish

- Fill `templates/confluence-release.html` (translate headings to `outputLanguage`).
- Create the page with `createConfluencePage`: `spaceId`, `parentId` (omit if empty),
  `contentFormat: html`, **`status: draft`**, title `"{releaseTitlePrefix} — {YYYY-MM-DD}"`
  (for date-window/sprint, the suffix reflects the period/sprint instead of just the date).
- **Do NOT auto-publish.** Present the draft link; the user reviews and clicks **Publish** in the
  Confluence UI. (Rationale: `updateConfluencePage` draft→current fails with
  *"version must be 1 when publishing for the first time"*, and there is no delete tool, so any
  auto-publish workaround leaves an orphan draft.)
- **Idempotency:** before creating, look for a page with the same title under the parent; if found,
  `updateConfluencePage` on that draft instead of duplicating.
- **Releases index:** if `parentId` is a folder, nest releases under a "Releases" **index page**
  inside the folder (the API creates pages, not native folders), creating the index once.

## 8. Slack (Phase 4) & guided cleanup (Phase 5)

Unchanged from v1, now per profile:
- Slack: fill `templates/slack-announcement.md` (labels in `outputLanguage`), present in a code
  block; never post.
- Cleanup: deliver `reference/board-clear-runbook.md` (substitute `{projectKey}`/`{jiraBaseUrl}`):
  plan check → bulk archive (recommended) or `released`-label fallback; re-access via the Confluence
  page, *Archived issues*, and card URLs.

## 9. Known constraints

- The Atlassian MCP runs JQL (incl. `openSprints()`/`closedSprints()`/`sprint = …`) but **does not
  list Agile sprints** → `last-closed` is resolved by inspecting the `sprint` field on returned cards.
- `updateConfluencePage` cannot publish a draft→current on first version; **publish is manual in the UI**.
- No delete tool in the MCP → never create throwaway drafts; create the intended draft once.
- The MCP does **not** create Confluence spaces or change board config/sprints.

## 10. Rename & migration mechanics

- Local: dir `infra-release-skill` → `board-release-skill`; symlink `~/.claude/skills/board-release`
  (remove `infra-release`); `name: board-release` in frontmatter; `SKILL_NAME` in `install.sh`;
  config dir `~/.config/board-release/`.
- GitHub: rename the repo in the UI, then `git remote set-url origin <new>`; commit + push on top.
- Config: import the legacy `~/.config/infra-release/config.yaml` as profile `infra` (see §4).

## 11. Out of scope (YAGNI)

- Persistent watermark/state between runs (each scope mode is self-determining).
- Skill transitioning/archiving cards or posting to Slack automatically.
- Auto-publishing the Confluence page (manual by design, per the gotcha).
- Creating Confluence spaces or Agile sprint admin.

## 12. Acceptance criteria

- [ ] `/board-release <profile>` selects a profile; no-arg behavior is 0→setup, 1→use, many→ask/default.
- [ ] Setup creates/edits one profile and can import the legacy `infra-release` config.
- [ ] Config is a single file with a `profiles` map; nothing board-specific in the skill files.
- [ ] Each scope mode (`done-now`/`date-window`/`sprint`) produces the right completed-cards set;
      `last-closed` isolates the most recently completed sprint.
- [ ] Per-profile themes override the seed themes; output rendered in the profile's language.
- [ ] Confluence page created as **draft**; skill never auto-publishes; idempotent re-runs update the draft.
- [ ] Guided cleanup runbook + re-access, per profile.
- [ ] Skill is **read-only on Jira** throughout.
- [ ] Renamed to `board-release` end-to-end (frontmatter, install.sh, symlink, repo, README/docs).
