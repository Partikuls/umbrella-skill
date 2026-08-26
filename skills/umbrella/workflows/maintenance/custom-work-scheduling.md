# Workflow — custom work scheduling

Create a **custom work** on a WP Umbrella project: a tracked maintenance task (one-time or recurring) that shows up in the project's work history and client maintenance reports. Use this whenever the user wants to log, schedule, or plan a piece of maintenance work on a site — not to *execute* an update right now (that's `safe-plugin-update.md`).

## User intents this covers

- *"Log 2 hours of SEO work on site X for today"*
- *"Schedule a monthly content review on project 123, every 1st of the month"*
- *"Add a recurring weekly plugin update task on Monday for site Y"*
- *"Create a quarterly performance audit task on all my client sites"*
- *"Track the custom CSS fix I did on X yesterday, 30 minutes"*

## Endpoint

`POST /projects/{projectId}/custom-works` — see `openapi-public.json` for the authoritative schema.

Only creation is exposed by the Public API today. There is **no** GET/PUT/DELETE for custom works — you cannot list, edit, or delete them through the API; tell the user to do that in the WP Umbrella dashboard.

### Request body

| Field | Required | Type / values | Notes |
|---|---|---|---|
| `name` | **yes** | string | Short title shown in the dashboard and reports |
| `description` | no | string | Free text |
| `execution_date` | **yes** | `YYYY-MM-DD` | Date the work is (or was) done; for recurring works, the first occurrence |
| `estimated_time` | **yes** | number | Duration value |
| `estimated_time_unit` | **yes** | `MINUTES` \| `HOURS` \| `DAYS` | Unit of `estimated_time` |
| `is_recurring` | no | boolean (default `false`) | Enables the recurrence fields below |
| `frequency` | if recurring | `WEEKLY` \| `MONTHLY` \| `QUARTERLY` | |
| `type_frequency` | if recurring | `MONDAY`…`SUNDAY` or `BEGIN_Q1`…`BEGIN_Q4` | Weekday for `WEEKLY`; quarter anchor for `QUARTERLY` |
| `specific_day` | if recurring | number | Day of month (1–31) for `MONTHLY`; required whenever `is_recurring` is `true` |
| `plugin_keys` | no | string[] | Plugin keys (`dir/file.php`) to associate with the work |
| `clear_cache` | no | boolean | Whether cache clearing is part of the work |

Recurrence combinations to use:

| User says | `frequency` | `type_frequency` | `specific_day` |
|---|---|---|---|
| every Monday | `WEEKLY` | `MONDAY` | `1` |
| every 15th of the month | `MONTHLY` | *(omit)* | `15` |
| every quarter, start of Q1 | `QUARTERLY` | `BEGIN_Q1` | `1` |

The API requires `specific_day` whenever `is_recurring` is `true` — send `1` for weekly/quarterly works if the user gave no day.

## Preconditions

- Token present (resolved per SKILL.md section 1)
- Project identified by name or ID — resolve the ID with `reporting/project-inventory.md` Step 3 if the user gave a name
- Abort if the user's request is actually "run an update now" → redirect to `safe-plugin-update.md`

## Step 1 — resolve the project

```bash
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://public-api.wp-umbrella.com/projects?per_page=200" \
  | jq '.data[] | select(.name | test("<NAME>"; "i")) | {id, name, base_url}'
```

If several projects match, ask the user which one. If the user asked for the same work on **several** sites, collect all IDs and create one custom work per project in Step 4 (one confirmation covering the whole batch is enough — list every site in the plan).

## Step 2 — gather the fields

Fill the required fields from the user's message. Ask **only** for what is missing, in a single question:

- `name` — derive from the request if obvious (*"SEO work"*, *"Monthly content review"*), otherwise ask
- `execution_date` — default to **today** when the user says "today"/"now" or gives no date; convert relative dates ("yesterday", "next Monday") to `YYYY-MM-DD` using the current date
- `estimated_time` + `estimated_time_unit` — normalize: "30 min" → `30 MINUTES`, "2h" → `2 HOURS`, "half a day" → `4 HOURS`, "a day" → `1 DAYS`
- Recurrence — only if the user said recurring/weekly/monthly/quarterly/every…

Do not invent a `description`; leave it out unless the user provided detail.

## Step 3 — present the plan and confirm

This is a **mutating call** — apply the SKILL.md section 5 gate. Show the exact payload in plain language:

```
Project: <name> (ID <id>)
Work     : Monthly content review
Date     : 2026-09-01
Estimate : 2 HOURS
Recurring: yes — MONTHLY, day 1
Plugins  : —
Create this custom work? (yes/no)
```

**Wait for explicit confirmation.** Do not proceed on ambiguous replies.

## Step 4 — create the custom work

One-time example:

```bash
curl -sS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "name": "SEO on-page work",
    "description": "Rewrote meta titles on 12 pages",
    "execution_date": "2026-08-26",
    "estimated_time": 2,
    "estimated_time_unit": "HOURS"
  }' \
  "https://public-api.wp-umbrella.com/projects/<ID>/custom-works" \
  | jq '{code, id: .data.id, name: .data.name, execution_date: .data.execution_date, is_recurring: .data.is_recurring, scheduledWorkId: .data.scheduledWorkId}'
```

Recurring example (every Monday, 30 minutes):

```bash
curl -sS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "name": "Weekly plugin update pass",
    "execution_date": "2026-09-01",
    "estimated_time": 30,
    "estimated_time_unit": "MINUTES",
    "is_recurring": true,
    "frequency": "WEEKLY",
    "type_frequency": "MONDAY",
    "specific_day": 1,
    "plugin_keys": ["wp-seopress/seopress.php"],
    "clear_cache": true
  }' \
  "https://public-api.wp-umbrella.com/projects/<ID>/custom-works" \
  | jq '{code, id: .data.id, scheduledWorkId: .data.scheduledWorkId}'
```

The response is **synchronous** — there is no `processId` to poll. `code: "success"` with a `data.id` means the work is created. Recurring works also return a `scheduledWorkId`.

## Step 5 — report

Tell the user, per project:

- ✅ *"Custom work #25 'Weekly plugin update pass' created on <site> — recurring weekly on Monday, first run 2026-09-01"*
- Mention `scheduledWorkId` only for recurring works (it's what the dashboard uses to identify the series)
- Remind them that edits/deletions happen in the WP Umbrella dashboard (Project → Maintenance / Custom works), since the API is create-only

## Error paths

| Response | What to do |
|---|---|
| `400` `bad_params` | A required field is missing or an enum value is wrong (e.g. `HOUR` instead of `HOURS`, `specific_day` missing on a recurring work). Re-read the table above, fix, and retry — do not re-ask for confirmation if the intended work is unchanged. |
| `401` `unauthorized_request` | Token missing/invalid → `references/auth.md` |
| `404` `not_found` | Wrong project ID → go back to Step 1 |
| Batch: one site fails | Report which sites succeeded and which failed; do not silently retry the failed ones |
