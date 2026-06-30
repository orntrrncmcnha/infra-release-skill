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
The config lives at `~/.config/board-release/config.yaml`
(see `config.example.yaml`).

## Layout

- `SKILL.md` — procedure + setup + config schema
- `config.example.yaml` — profiles config format
- `reference/` — JQL recipes (scope variants), translation guide, cleanup runbook
- `templates/` — Confluence page HTML, Slack mrkdwn
- `docs/` — SPEC and PLAN
