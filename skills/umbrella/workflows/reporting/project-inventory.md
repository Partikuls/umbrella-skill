# Workflow — project inventory

Fetch, filter, drill into, and summarize the user's WP Umbrella projects. This is the **foundation workflow** — most other playbooks start by identifying which project(s) to operate on, so they reference this one.

## User intents this covers

- *"List my sites"* / *"Show me my projects"*
- *"Which sites are down right now?"*
- *"Which sites have plugin updates pending?"*
- *"Which sites have known vulnerabilities?"*
- *"Give me a health snapshot of my entire fleet"*
- *"Find the site called X"* (name → ID resolution)
- *"Export my site list to CSV"*

## Endpoint

`GET /projects` — paginated, embeds summaries of plugins, themes, vulnerabilities, warnings, customer.

For full detail on a single site: `GET /projects/{projectId}`.

Key query params:

| Param | Default | Notes |
|---|---|---|
| `page` | `1` | — |
| `per_page` | `10` | Higher values supported; use `100-200` for fleet operations |
| `sort` | `name` | or `base_url` |
| `order` | `asc` | or `desc` |

## Step 1 — quick listing

When the user just wants "my sites":

```bash
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://public-api.wp-umbrella.com/projects?per_page=50" \
  | jq '.data[] | {id, name, base_url, is_currently_down, latest_ping}'
```

Present as a compact table. Don't dump nested structures on the user.

## Step 2 — filtered views

### Down right now

```bash
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://public-api.wp-umbrella.com/projects?per_page=200" \
  | jq '.data[] | select(.is_currently_down == true)
      | {id, name, base_url, latest_downtime}'
```

### Plugin updates pending

```bash
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://public-api.wp-umbrella.com/projects?per_page=200" \
  | jq '[.data[]
      | {id, name, base_url,
         pending: [.plugins[] | select(.need_update == true) | .slug]}
      | select(.pending | length > 0)]'
```

### Known vulnerabilities

```bash
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://public-api.wp-umbrella.com/projects?per_page=200" \
  | jq '[.data[]
      | {id, name, base_url,
         vuln_count: ((.vulnerabilities.plugins|length)
                     + (.vulnerabilities.themes|length)
                     + (.vulnerabilities.wordpress|length))}
      | select(.vuln_count > 0)]'
```

### WordPress core out of date

```bash
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://public-api.wp-umbrella.com/projects?per_page=200" \
  | jq '.data[] | select(.warnings.is_up_to_date == false)
      | {id, name, wp: .warnings.wordpress_version}'
```

### PHP unsupported / insecure

```bash
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://public-api.wp-umbrella.com/projects?per_page=200" \
  | jq '.data[]
      | select(.warnings.php_is_supported == false
            or .warnings.php_is_secure == false)
      | {id, name,
         php: .warnings.php_current_version,
         recommended: .warnings.php_recommended_version,
         secure: .warnings.php_is_secure}'
```

## Step 3 — name → ID resolution

Used by any workflow that receives a site name from the user:

```bash
NAME="<user input>"
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://public-api.wp-umbrella.com/projects?per_page=200" \
  | jq --arg n "$NAME" '.data[]
      | select((.name | test($n; "i")) or (.base_url | test($n; "i")))
      | {id, name, base_url}'
```

If zero matches → ask the user to rephrase or list their sites. If multiple matches → present the shortlist and ask which one. **Never guess.**

## Step 4 — drill-down on a specific project

Once the ID is known:

```bash
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://public-api.wp-umbrella.com/projects/<ID>"
```

Present a curated summary, not the raw JSON:

- **Status**: `is_currently_down`, `latest_ping`, `latest_performance_score`
- **Stack**: `warnings.wordpress_version`, `warnings.php_current_version`
- **Outdated plugins**: `plugins[] | select(.need_update)` — list name + current → new
- **Vulnerabilities**: counts for plugins/themes/core; hoist worst CVSS
- **Last sync**: `last_synchronization.date_with_success`
- **Customer**: `maintenanceCustomer.company_name` (if any)

For the full plugin or theme list, use `/projects/{ID}/plugins` and `/projects/{ID}/themes` (the embedded arrays on `/projects/{ID}` are summaries).

## Step 5 — paginate through every project (fleet-wide)

For reports that must cover every site, walk all pages:

```bash
PAGE=1
OUT=$(mktemp)
while :; do
  RESP=$(curl -sS -H "Authorization: Bearer $TOKEN" \
    "https://public-api.wp-umbrella.com/projects?page=$PAGE&per_page=100")
  echo "$RESP" | jq -c '.data[]' >> "$OUT"
  NEXT=$(echo "$RESP" | jq -r '.links.pagination.next // empty')
  [ -z "$NEXT" ] && break
  PAGE=$((PAGE + 1))
done
echo "Collected $(wc -l < "$OUT") projects in $OUT"
```

Then run jq over `$OUT` (one JSON object per line — use `jq -s` to treat as array if needed).

## Step 6 — fleet health snapshot

When the user asks *"status of everything"*:

```bash
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://public-api.wp-umbrella.com/projects?per_page=200" \
  | jq '{
      total: (.data | length),
      down: [.data[] | select(.is_currently_down)] | length,
      with_pending_updates:
        [.data[] | select(any(.plugins[]; .need_update == true))] | length,
      with_vulnerabilities:
        [.data[] | select(((.vulnerabilities.plugins|length)
                          + (.vulnerabilities.themes|length)
                          + (.vulnerabilities.wordpress|length)) > 0)] | length,
      outdated_wp:
        [.data[] | select(.warnings.is_up_to_date == false)] | length,
      unsupported_php:
        [.data[] | select(.warnings.php_is_supported == false)] | length
    }'
```

Present as a dashboard. Offer the affected lists as follow-ups ("want the names?").

## Step 7 — export to CSV

```bash
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://public-api.wp-umbrella.com/projects?per_page=200" \
  | jq -r '
      ["id","name","url","down","php","wp","up_to_date"],
      (.data[] | [.id, .name, .base_url, .is_currently_down,
                  .warnings.php_current_version,
                  .warnings.wordpress_version,
                  .warnings.is_up_to_date])
      | @csv'
```

Redirect to a file if the user wants to share: `... > sites.csv`.

## Notes

- **Don't over-fetch.** For simple questions, `per_page=50` is usually enough. Only do Step 5 (full pagination) when the user explicitly asks for fleet-wide data.
- **Embedded summaries vs detail endpoints.** `/projects` returns a *summary* of plugins/themes/vulnerabilities. For full lists, use the dedicated endpoints under `/projects/{ID}/...`.
- **Starred projects**: the `starred` field flags the user's pinned favorites — useful when they ask about "my main sites."
