---
name: infra-release
description: Use when closing out a Jira board in release cycles — generates a stakeholder release page in Confluence (as a draft) from completed cards, a roadmap of in-progress/selected work, and a Slack announcement to post manually. Read-only on Jira; runs an interactive first-time setup (site, board, statuses, Confluence space, output language).
---

# infra-release

Closes a Jira board in release cycles: produces a **stakeholder** release (not a tech report),
a roadmap of what's coming, and a ready-to-post Slack announcement.

**Guarantees:** Read-only on Jira (never transitions/archives/edits). Confluence always as a
**draft**. Slack is **never** posted automatically.

## Config (per user, outside the repo)

File: `${XDG_CONFIG_HOME:-$HOME/.config}/infra-release/config.yaml`.
Format in `config.example.yaml`. Fields:

```yaml
cloudId: ""                       # Atlassian site (UUID)
jiraBaseUrl: ""                   # e.g. https://yoursite.atlassian.net
projectKey: ""                    # e.g. OPS
doneStatusCategory: "Done"        # status category of completed cards (these go into the release)
inProgressStatusCategory: "In Progress"
nextStatusName: ""                # the "coming up" status (e.g. "To Do" / "Ready"); empty = skip
confluence:
  spaceId: ""                     # space where the page is created
  parentId: ""                    # parent folder or page (optional; empty = space root)
releaseTitlePrefix: "Release Notes"  # title prefix; the final title gets " — YYYY-MM-DD"
outputLanguage: "English"         # language of the generated release (Confluence + Slack)
```

No site/board/space is baked into the skill — everything comes from this file.

## Setup phase (first run, or when config is missing/incomplete)

On start, read the config. If it doesn't exist or a required field is missing
(`cloudId`, `projectKey`, `confluence.spaceId`, `outputLanguage`), run setup:

1. **Atlassian site:** call `getAccessibleAtlassianResources`. If there's more than one site,
   list them and ask the user to choose → store `cloudId` and `jiraBaseUrl` (the resource `url`).
2. **Board/project:** offer `getVisibleJiraProjects` (or ask for the key) → store `projectKey`.
3. **Status mapping:** confirm `doneStatusCategory`/`inProgressStatusCategory` (defaults above).
   For "coming up", list the project statuses (use `getTransitionsForJiraIssue` on a sample card
   with `includeUnavailableTransitions: true`) and ask which one represents "selected for delivery"
   → store `nextStatusName` (or leave empty to skip that section).
4. **Confluence:** call `getConfluenceSpaces` → ask for the space → store `spaceId`. Ask for the
   `parentId` (parent folder/page) or leave it empty.
5. **Title:** ask for `releaseTitlePrefix` (default "Release Notes").
6. **Output language:** ask which language the release communication (Confluence page + Slack text)
   should be written in → store `outputLanguage` (default "English").
7. Write `config.yaml` (create the dir with `mkdir -p`) and show the user a summary.

Reconfigure = delete `config.yaml` and run again, or explicitly ask to "redo setup".

## Procedure (5 phases, with checkpoints ✋)

All `{...}` values come from the config. **Write every human-facing string in the generated
release — section headings included — in `{outputLanguage}`, with correct orthography and
diacritics (never strip accents).**

### Phase 0 — Scope ✋
Count the completed cards (`computeIssueCount`) and confirm: "close everything completed in board
`{projectKey}` now?". Only proceed with the OK.

### Phase 1 — Collect (read-only)
Run the three queries in `reference/jql-recipes.md`, substituting placeholders from the config
(`{projectKey}`, `{nextStatusName}`, etc.). Paginate and extract with `jq` per the guide.
Filter by `statusCategory`, never by a localized status name.

### Phase 2 — Synthesize
Apply `reference/business-translation.md`: group completed cards by business theme and write the
TL;DR + per-theme paragraphs (non-technical, quantified) in `{outputLanguage}`. Build the roadmap
from IN_PROGRESS + SELECTED. Cards you can't confidently theme go to a "Review" note.

### Phase 3 — Confluence (draft) ✋
Fill `templates/confluence-release.html` (marker `{{RELEASE_TITLE}}` = `{releaseTitlePrefix}`),
translating the template's section headings and labels into `{outputLanguage}`. Create the page
with `createConfluencePage`: `spaceId = {confluence.spaceId}`, `parentId = {confluence.parentId}`
(omit if empty), `contentFormat: html`, `status: draft`,
title = `"{releaseTitlePrefix} — {YYYY-MM-DD}"`.
**Idempotency:** before creating, look for a page with the same title; if it exists,
`updateConfluencePage` on the draft instead of duplicating.
If `parentId` is a folder and the API rejects it, create/use a releases index page under the folder
and nest the release there.
Present the draft link and ask for review before publishing.

### Phase 4 — Slack (manual) ✋
Fill `templates/slack-announcement.md` with the page URL (labels in `{outputLanguage}`) and present
the result **inside a code block** for the user to copy. **Do not post.**

### Phase 5 — Guided cleanup ✋
Deliver the contents of `reference/board-clear-runbook.md` (substituting `{projectKey}` and
`{jiraBaseUrl}`): plan check + path A/B + re-access. The skill does **not** transition or archive
anything.

## Safety rails
- NEVER call issue transition/edit/archive on Jira.
- NEVER post to Slack.
- Confluence only as `draft` until explicit OK.
