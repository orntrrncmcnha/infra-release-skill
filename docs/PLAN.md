# infra-release-skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Build the `infra-release` skill — closes a Jira board by generating a stakeholder release
in Confluence (draft), a roadmap, and a Slack text to post manually, while staying read-only on Jira.
Generic: site/board/space/language come from an interactive setup.

**Architecture:** A native Claude Code procedural skill. `SKILL.md` orchestrates the setup + 5 phases
(scope → collect via MCP → synthesize → publish draft to Confluence → manual Slack → guided cleanup).
Templates and guides live in `templates/` and `reference/`. No runtime of its own: the executor is
Claude using the Atlassian MCP. Per-user config lives outside the repo.

**Tech Stack:** Markdown, HTML (Confluence template), Bash (install.sh), Atlassian MCP.
Verification via `grep`, `bash -n`, `python3` (stdlib), and a real symlink install.

## Global Constraints

- **Read-only on Jira:** never transitions/archives/edits issues.
- **Confluence draft-first:** pages with `status: draft` until the user's OK.
- **Slack:** never posts automatically.
- **No hardcoding:** no specific site/board/space/project in the skill — all from the per-user config
  (`${XDG_CONFIG_HOME:-$HOME/.config}/infra-release/config.yaml`).
- **Skill files in English; release output in the configured `outputLanguage`** (correct diacritics).
- **Status by category:** filter by `statusCategory`, never by a localized name.
- **Idempotency:** if a page with the same title exists, update the draft (don't duplicate).
- Standalone git repo.

## File Structure

| File | Responsibility |
|------|----------------|
| `README.md` | What it is, how to install, how to run |
| `.gitignore` | OS/editor junk + local `config.yaml` |
| `config.example.yaml` | Per-user config format |
| `install.sh` | Symlink `~/.claude/skills/infra-release` → repo + validation |
| `reference/jql-recipes.md` | JQL queries (placeholders) + pagination + jq |
| `reference/business-translation.md` | Technical→business rules + generic seed themes |
| `reference/board-clear-runbook.md` | Guided cleanup (placeholders) + re-access |
| `templates/confluence-release.html` | HTML template (TL;DR/themes/appendix/roadmap) |
| `templates/slack-announcement.md` | mrkdwn template |
| `SKILL.md` | Core: interactive setup + config schema + 5 phases |
| `docs/SPEC.md`, `docs/PLAN.md` | Design and plan |

## Tasks

### Task 1 — Scaffold + git
- [x] `git init`; `.gitignore` (includes `config.yaml`); English `README.md`.
- Verify: README mentions "Read-only on Jira", "draft-first", "Slack manual", "/infra-release",
  "interactive setup". Commit.

### Task 2 — Generic config
- [x] `config.example.yaml` with all fields (cloudId, jiraBaseUrl, projectKey, status mapping,
  confluence.spaceId/parentId, releaseTitlePrefix, outputLanguage), all empty/default.
- Verify: `grep` the fields. Commit.

### Task 3 — reference/jql-recipes.md
- [x] 3 queries with `{{PROJECT_KEY}}`/`{{NEXT_STATUS}}`; the `statusCategory` vs localized-name note;
  pagination + `jq` examples.
- Verify: `grep` for `{{PROJECT_KEY}}`, `statusCategory = Done`, `nextPageToken`, `jq -r`. Commit.

### Task 4 — reference/business-translation.md
- [x] Rules (impact > mechanism, quantify, zero jargon, group by theme, never invent); generic seed
  themes; generic examples (no proper nouns); render in `outputLanguage`.
- Verify: `grep` for "Lead with impact", "Zero jargon", "Seed themes", "Review". Commit.

### Task 5 — reference/board-clear-runbook.md
- [x] Plan check + Path A (archive) + Path B (`released` label) + re-access, with
  `{{PROJECT_KEY}}`/`{{JIRA_BASE_URL}}`.
- Verify: `grep` for "Step 0", "Path A", "Path B", "Re-access". Commit.

### Task 6 — templates
- [x] `confluence-release.html` with markers `{{RELEASE_TITLE}}/{{PERIOD}}/{{TLDR_ITEMS}}/`
  `{{THEMES}}/{{ROADMAP}}/{{APPENDIX_ROWS}}/{{REVIEW}}`; `slack-announcement.md` with
  `{{RELEASE_TITLE}}/{{PERIOD}}/{{BULLETS}}/{{CONFLUENCE_URL}}`. Headings to be localized.
- Verify: `grep` the markers + HTML parse (`python3 html.parser`). Commit.

### Task 7 — SKILL.md
- [x] Frontmatter `name: infra-release` + config schema + interactive Setup phase (incl. output
  language) + 5 phases referencing the files and config values; safety rails.
- Verify: `grep` for `^name: infra-release`, `^description:`, "Setup phase", "Phase 0..5",
  "status: draft", "Read-only on Jira"; all referenced files exist. Commit.

### Task 8 — install.sh + smoke test
- [x] Symlink `~/.claude/skills/infra-release` → repo, with `SKILL.md`/`name:` validation, idempotent.
- Verify: `bash -n`; run `./install.sh`; symlink exists; `SKILL.md` reachable; rerun OK. Commit.

## Final verification

- [x] No specific site/board/space/proper-noun in versioned files
  (`grep -ri` for specific terms returns empty).
- [x] Skill discoverable as `infra-release`.
- [ ] **E2E acceptance:** run `/infra-release` on a real board, go through setup, generate the draft.
