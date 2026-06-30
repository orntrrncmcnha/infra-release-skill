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
