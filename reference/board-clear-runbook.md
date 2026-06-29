# Runbook — guided board cleanup + re-access

Replace `{{PROJECT_KEY}}` and `{{JIRA_BASE_URL}}` with config values.
The skill is **read-only on Jira**: it only hands you these steps; **you (the admin) execute them**.

## Step 0 — check the plan (do this once)

In the issue navigator, open `project = {{PROJECT_KEY}} AND statusCategory = Done` and check whether
**Bulk change → Archive issues** appears.
- **It appears** → use **Path A** (Premium/Enterprise).
- **It doesn't** → Standard plan, use **Path B**.

## Path A — bulk archive (recommended)

1. Issue navigator → `project = {{PROJECT_KEY}} AND statusCategory = Done`.
2. Select all → **Bulk change → Archive issues** → confirm.

Why archive (not delete): archived issues disappear from the board **and** from normal searches, but
stay **recoverable**. Bonus: since they drop out of `statusCategory = Done`, the **next closing
won't re-pick them** — that's what makes the "close everything completed now" model work without
keeping state between runs.

## Path B — fallback (Standard, no archiving)

1. Bulk edit: add the label `released` to all completed cards.
2. Board settings → adjust the **sub-filter** to hide `statusCategory = Done` with that label
   (or hide completed by age).
3. On later runs, the completed query becomes:
   `project = {{PROJECT_KEY}} AND statusCategory = Done AND labels != released`.

## Re-access (after they disappear)

1. **The Confluence page** — canonical source: by theme, with a link per card.
2. **Jira** — nothing is deleted:
   - *Archived issues* (admin view) to see/restore (Path A).
   - Any card opens via `{{JIRA_BASE_URL}}/browse/{{PROJECT_KEY}}-XXX`, even archived.
   - Path B: `project = {{PROJECT_KEY}} AND labels = released`.
3. **The releases index** in Confluence — history of every closing.
