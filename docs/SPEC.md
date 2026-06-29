# SPEC — infra-release-skill

**Status:** implemented
**Repository:** standalone git repo (a publishable Claude Code skill)

---

## 1. Problem

Jira boards accumulate cards in the "done" column. Before cleaning the board, we want to:

1. Know, as an admin, **what to do so finished cards disappear** from the board.
2. Know **how to re-access** those cards after they disappear.
3. Produce a **closing (release) text** of the completed work, for stakeholders — for the **company**
   to understand, not the engineering team. Without going card by card.
4. Give an **overview of what's in progress and what's selected for delivery**.

All of it as a **skill reusable on any board** — with nothing baked in about a specific board,
site, or space.

## 2. Design decisions

| # | Decision | Choice |
|---|----------|--------|
| Scope per run | Which completed cards are included | **Everything completed at that moment** (no persistent watermark) |
| Output destination | Where it publishes | **Confluence** (official) + **Slack** (text the user posts; the skill never posts) |
| Disappear from board | Mechanism | **Guided manual cleanup** — skill is **read-only on Jira**; hands over a runbook, the user executes |
| Build approach | | **Pure procedural skill** (SKILL.md + templates + reference) |
| Configuration | How it gets site/board/space/language | **Interactive first-run setup**, persisted in a per-user config outside the repo |
| Content structure | 1 or 2 pages | **A single page**: Delivered → In progress → Coming up |
| Jira plan (archive) | Premium? | **Runbook checks at runtime** and branches (archive vs fallback) |
| Output language | | **Asked at setup**, stored as `outputLanguage`; release content rendered in it |

## 3. Known technical constraints

- The Atlassian MCP transitions issues, runs JQL, and creates/edits Confluence pages
  (`createConfluencePage` accepts `parentId` and `status: draft`). It does **NOT** touch board config
  (columns/sub-filters/sprints) nor archive issues. → that's why "disappear from board" is guided.
- Searching status by **localized name** can return empty on translated sites. **Mitigation:** filter
  by `statusCategory`.
- The MCP **does not create Confluence spaces** — the target space must already exist.

## 4. Skill architecture

Procedural skill. Repo layout:

```
infra-release-skill/
├── SKILL.md                         # core: setup + config schema + the 5-phase procedure
├── README.md
├── install.sh                       # symlink to ~/.claude/skills/infra-release + validation
├── config.example.yaml              # per-user config format
├── templates/
│   ├── confluence-release.html      # page HTML template
│   └── slack-announcement.md        # post mrkdwn template
├── reference/
│   ├── jql-recipes.md               # queries (placeholders {{PROJECT_KEY}}/{{NEXT_STATUS}})
│   ├── business-translation.md      # technical → business-impact guide
│   └── board-clear-runbook.md       # guided cleanup + re-access (placeholders)
└── docs/
    ├── SPEC.md
    └── PLAN.md
```

**Per-user config** (outside the repo, at `${XDG_CONFIG_HOME:-$HOME/.config}/infra-release/config.yaml`):
`cloudId`, `jiraBaseUrl`, `projectKey`, `doneStatusCategory`, `inProgressStatusCategory`,
`nextStatusName`, `confluence.spaceId`, `confluence.parentId`, `releaseTitlePrefix`, `outputLanguage`.

## 5. Execution flow

**Setup (first run or incomplete config):** discovers the site via `getAccessibleAtlassianResources`,
offers projects via `getVisibleJiraProjects`, confirms the status mapping, lists spaces via
`getConfluenceSpaces`, asks for the title prefix and the output language — and writes the config.

**5 phases (with checkpoints ✋):**

| Phase | Action | Writes? | Checkpoint |
|-------|--------|---------|-----------|
| 0. Scope | Count completed and confirm the closing | — | ✋ confirm |
| 1. Collect | JQL completed + in progress + selected; paginate; extract with `jq` | no | — |
| 2. Synthesize | Group by business theme; write release + roadmap (non-technical, in `outputLanguage`) | no | — |
| 3. Confluence | Create the page as a **draft** in the configured space/folder | yes (draft) | ✋ review before publishing |
| 4. Slack | Generate mrkdwn text (headline + bullets + link) in a code block | no (only generates) | ✋ post manually |
| 5. Guided cleanup | Hand over the runbook + re-access recipe | no | ✋ execute on Jira |

## 6. Content (single page)

1. **Executive summary (TL;DR)** — 4-6 impact bullets.
2. **Deliveries by theme** — one non-technical paragraph per theme, cards folded in.
3. **Appendix — traceability** — a `Card | Summary | Theme` table with links.
4. **What's coming (roadmap)** — "In progress" + "Selected for delivery", by theme.
5. **"Review" notes** (if any) — cards needing a human theming decision.

Translation rules in `reference/business-translation.md`. Seed themes are a starting point,
adjustable per board. All human-facing strings are rendered in `outputLanguage`.

## 7. Guided cleanup + re-access

Runbook in `reference/board-clear-runbook.md`: plan check → bulk archive (recommended) or fallback
with a `released` label. Re-access via the Confluence page (canonical), the *Archived issues* view,
and each card's URL.

## 8. Out of scope (YAGNI)

- Persistent watermark/state between runs (decision: "everything completed now").
- The skill transitioning/archiving cards automatically (decision: guided cleanup).
- The skill posting to Slack automatically (decision: the user posts).
- Creating a Confluence space (the MCP can't).

## 9. Acceptance criteria

- [x] The skill is **read-only on Jira** throughout.
- [x] Interactive setup writes a per-user config; nothing specific is baked into the skill.
- [x] Skill files are in English; release output is rendered in the chosen `outputLanguage`.
- [x] Page created as a **draft** in the configured space/folder, date-stamped title.
- [x] Page has TL;DR + deliveries by theme + appendix + roadmap, in non-technical language.
- [x] Slack text generated as mrkdwn, in a code block, with **no** automatic posting.
- [x] Cleanup runbook with plan check + paths A/B + re-access.
- [x] Re-running doesn't duplicate the page (updates the draft).
- [x] `install.sh` makes the skill available under `~/.claude/skills/`.
