---
name: health
description: Dashboard-style snapshot of overall WP Umbrella fleet health in one call — totals of sites down, pending updates, vulnerabilities, outdated WordPress, unsupported PHP. Invoke as /umbrella:health.
user-invocable: true
---

# /umbrella:health

Run the fleet health snapshot from `skills/umbrella/workflows/reporting/project-inventory.md`, **Step 6 "Fleet health snapshot"**.

## Expected output

Present the dashboard as a compact summary (not raw JSON):

```
Fleet health
────────────────────────────────────────
Total sites        : 42
Down right now     :  1
Pending updates    : 12
Vulnerabilities    :  3
Outdated WP core   :  5
Unsupported PHP    :  2
```

## Follow-up

After showing the dashboard, proactively offer to drill in:

> *"Want me to list the affected sites in any of these categories?"*

If the user picks one, switch to the corresponding filter in Step 2 of the project-inventory workflow.

## Setup

Before the first call this session, make sure the token is resolved (see `skills/umbrella/SKILL.md` section 1). If no token is present, stop and walk the user through `skills/umbrella/references/auth.md`. Do **not** ask them to paste the token into chat.
