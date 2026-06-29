# infra-release-skill

A Claude Code skill that **closes a Jira board in release cycles** and produces a
**stakeholder release** in Confluence, a **roadmap** of what's coming, and a ready-to-post
**Slack announcement** — without going card by card and without reading like a tech report.

Works with **any Jira board**: on the first run, the skill runs an **interactive setup**
(discovers the Atlassian site, asks for the board, the statuses, the Confluence space, and the
output language) and stores the configuration in a per-user file. Nothing about a board/site/space
is baked into the skill.

## What it does

1. Reads the board's **completed** cards (read-only, via the Atlassian MCP).
2. Translates the technical work into **business impact**, grouped by theme.
3. Creates a **release page** in Confluence as a **draft**.
4. Generates a **Slack announcement** (mrkdwn) for you to post manually.
5. Hands you a **guided cleanup runbook** for the board + how to **re-access** the cards later.

The release output (Confluence page + Slack text) is written in the **language you choose during
setup**; the skill files themselves are in English.

## Guarantees

- **Read-only on Jira:** never transitions, archives, or edits issues.
- **Confluence draft-first:** the page starts as a draft until your OK.
- **Slack manual:** the skill never posts on its own.

## Install

```bash
./install.sh
```
Creates a symlink at `~/.claude/skills/infra-release`. Restart your Claude Code session.

## Usage

```
/infra-release
```
On the first run, answer the setup. The config lives at
`${XDG_CONFIG_HOME:-$HOME/.config}/infra-release/config.yaml` (see `config.example.yaml`).
To reconfigure, delete that file or ask to "redo setup".

## Layout

- `SKILL.md` — procedure + setup + config schema
- `config.example.yaml` — per-user configuration format
- `reference/` — JQL recipes, translation guide, cleanup runbook
- `templates/` — Confluence page HTML, Slack mrkdwn
- `docs/` — SPEC and PLAN
