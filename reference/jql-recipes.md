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
> Intentional exception to the "filter by category" rule above: `nextStatusName` is a specific
> custom status, so it is matched by `status =`, not by `statusCategory`.

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
