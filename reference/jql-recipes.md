# JQL recipes — collection (Phase 1)

Replace `{{PROJECT_KEY}}` and `{{NEXT_STATUS}}` with config values (`projectKey`, `nextStatusName`).
Use the `cloudId` from the config on every call.

> **Always filter by status category, not by name.** On localized sites, searching by a translated
> status name (e.g. `status = "Em andamento"`) can return empty. `statusCategory` is stable.

## Queries

**COMPLETED** (go into the release):
```
project = {{PROJECT_KEY}} AND statusCategory = Done ORDER BY resolutiondate DESC
```

**IN_PROGRESS** (roadmap — "in flight"):
```
project = {{PROJECT_KEY}} AND statusCategory = "In Progress" ORDER BY updated DESC
```

**SELECTED** (roadmap — "coming up"; only if `nextStatusName` is set):
```
project = {{PROJECT_KEY}} AND status = "{{NEXT_STATUS}}" ORDER BY updated DESC
```

## Fields to request

`["key","summary","description","issuetype","labels","components","assignee","resolutiondate","parent","updated"]`

Markdown body: pass `responseContentFormat: "markdown"` for readable descriptions.

## Pagination + extraction

1. Call `searchJiraIssuesUsingJql` with `maxResults: 100`.
2. If the response exceeds the tool's token limit, it is saved to a file automatically —
   read it with `jq` instead of dumping it into context.
3. Repeat with `nextPageToken` until `pageInfo.hasNextPage = false`.

Examples of `jq` extraction over the saved file `$F`:
```bash
# compact inventory: key + type + summary
jq -r '.issues.nodes[] | "\(.key)\t\(.fields.issuetype.name)\t\(.fields.summary)"' "$F"
# labels per card (for theming)
jq -r '.issues.nodes[] | "\(.key)\t\(.fields.labels | join(","))"' "$F"
# count per status category (sanity)
jq -r '.issues.nodes[] | .fields.status.statusCategory.name' "$F" | sort | uniq -c
```

## Counting (when you need the total)

Use `computeIssueCount: true` with `maxResults: 1` on a count-only query — don't combine it with real pagination.
