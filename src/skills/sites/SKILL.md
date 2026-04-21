---
name: sites
description: Power-user shortcut to list WP Umbrella sites with an optional filter. Invoke as /umbrella:sites [filter]. Filter can be "down", "updates", "vulns", "outdated", "php", or a name search.
user-invocable: true
argument-hint: [filter]
---

# /umbrella:sites

Shortcut to the project-inventory workflow. Take `$1` and map it to the right step of `skills/umbrella/workflows/reporting/project-inventory.md`.

## Argument mapping

| `$1` | Action |
|---|---|
| *(empty)* / `all` | Step 1 — quick listing |
| `down` | Step 2 — "Down right now" |
| `updates` / `update` | Step 2 — "Plugin updates pending" |
| `vulns` / `vulnerabilities` / `vuln` | Step 2 — "Known vulnerabilities" |
| `outdated` / `wp` | Step 2 — "WordPress core out of date" |
| `php` | Step 2 — "PHP unsupported / insecure" |
| anything else | Step 3 — treat `$1` as a site name search |

## Setup

Before the first call this session, make sure the token is resolved (see `skills/umbrella/SKILL.md` section 1). If no token is present, stop and walk the user through `skills/umbrella/references/auth.md`. Do **not** ask them to paste the token into chat.

## Arguments received

`$ARGUMENTS`
