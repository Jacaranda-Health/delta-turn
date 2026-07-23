# delta_turn

dbt project that transforms raw **Turn.io (WhatsApp)** data into clean, BI-ready
metrics for the **DELTA 2.0** provider-training programme (Kenya), served to a
Power BI dashboard.

Data flows: **Airbyte → ClickHouse (`turn_kenya`, raw) → dbt (`dev_munene`) → Power BI.**
All metric logic lives in dbt; Power BI reads final values only.

---

## The five Go-Live metrics

| Metric | Definition | Where it lives |
|--------|-----------|----------------|
| **Total enrolled users** | Distinct contacts who have initiated any DELTA flow (cumulative) | `delta_kpis_daily.enrolled_cumulative` |
| **Message success rate** | Outbound messages reaching `delivered`/`read` ÷ sent | `delta_kpis_daily.message_success_rate` |
| **Response latency** | Seconds from a user trigger to DELTA's first reply | `session_latency` (per session) + `delta_kpis_daily.median_latency_seconds` (per day) |
| **Downtime rate** | Failed operations ÷ total operations | `delta_kpis_daily.downtime_rate` |
| **Module completion rate** | Contacts who answered all questions in a module ÷ started, per module | `module_completion_daily` |

**Modules** roll up to four canonical tracks: **PPH, Communication, RMC, APH.**
(Climate & Health was retired.) Classification is by flow *title* pattern — note APH
uses a word-boundary regex (`\baph`) so it never matches "provider_demogr**aph**ics".

---

## Project structure

```
packages.yml               dbt_utils
models/
  staging/       stg_turn__*     deduped tables over the raw Turn sources (explicit columns)
  intermediate/  int_flow_responses, int_module_responses,
                 int_message_events, int_message_status, int_delta_sessions
  utilities/     dim_date, dim_month        date/month spines (dbt_utils.date_spine)
  metrics/       daily_kpis, module_completion     ALL aggregation lives here
  marts/         delta_kpis_daily, module_completion_daily, session_latency
macros/          generate_schema_name        forces every model into dev_munene
tests/           assert_latency_*, assert_unmatched_inbound, assert_message_timestamp_parses
```

Layering: **sources → staging → intermediate → metrics → marts.** Marts contain no
aggregation — they're thin, documented final selects that Power BI reads.
Run `dbt docs generate && dbt docs serve` to browse the DAG and column docs.

---

## Setup

**Prerequisites:** Python venv with `dbt-clickhouse`, access to the ClickHouse
service, and a user with write on the `dev_munene` dev schema.

1. **Activate the environment**
   ```powershell
   C:\Users\<you>\Documents\dbt_test\dbt-env\Scripts\Activate.ps1
   cd delta_turn
   ```

2. **Install packages**
   ```powershell
   dbt deps
   ```

3. **Set credentials** (per terminal session — never hardcode). The host must be the
   bare hostname (no `https://` — `secure: true` adds it).
   ```powershell
   $env:CLICKHOUSE_HOST='tplb1fkekn.eu-west-2.aws.clickhouse.cloud'
   $env:CLICKHOUSE_USER='<user>'
   $env:CLICKHOUSE_PASSWORD = Read-Host "CH password"
   ```

4. **`~/.dbt/profiles.yml`** (gitignored) — models build to `dev_munene`:
   ```yaml
   delta_turn:
     target: dev
     outputs:
       dev:
         type: clickhouse
         host: "{{ env_var('CLICKHOUSE_HOST') }}"
         port: 8443
         user: "{{ env_var('CLICKHOUSE_USER') }}"
         password: "{{ env_var('CLICKHOUSE_PASSWORD') }}"
         schema: dev_munene
         secure: true
         verify: false
         check_exchange: false
   ```

5. **Test the connection**
   ```powershell
   dbt debug
   ```

---

## Running

```powershell
dbt build                        # run all models + tests
dbt build --select daily_kpis+   # a model AND everything downstream (the + matters)
dbt test                         # data tests only
dbt docs generate                # build catalog + lineage
dbt docs serve --port 8081       # browse docs
```

`+` is a graph operator: `model+` = model and its children, `+model` = model and its
parents. Use it whenever a change needs to reach the marts Power BI reads.

---

## Conventions

- **Governance:** raw sources in `turn_kenya` are read-only; models write only to
  `dev_munene`. A `generate_schema_name` macro forces every model into that schema.
- **Dedup:** staging keeps the latest row per key (`limit 1 by <key>`) on
  `ReplacingMergeTree` tables. Keep this even if upstream dedup is fixed — it's what
  protected the metrics while the raw feed was ~5× duplicated.
- **Gap-free days:** `dim_date` provides the daily spine, so every day in the active
  range has a row. **Counts are 0-filled; latency is NULL** on days with no replied
  sessions (0 seconds would be a false reading and skews averages).
- **Rates are decimal ratios (0–1)**, never percentages — `0.308`, not `30.8`. The `%`
  is Power BI's display formatting.
- **Latency aggregation:** the headline card uses a true `MEDIAN` over `session_latency`
  (session grain). Never average the daily medians — a mean of medians isn't a median.
- **Module completion** uses an "answered all questions in the module" proxy, pending
  flow-level completion markers from JHOSS.
- **`max_reply_window_seconds`** (var, default 3600) bounds how far after a trigger a
  reply still counts as a response.

---

## Tests

- Staging keys: `not_null` + `unique` on `id` / `row_hash` / `page_id`.
- `module_name` / `direction`: `accepted_values`.
- `int_message_events.event_ts`: `not_null` — guards against upstream type drift
  silently breaking the epoch parse.
- `assert_latency_non_negative` (**error**) — a negative latency would mean a backward
  ASOF match.
- `assert_latency_within_window`, `assert_unmatched_inbound` (**warn**) — informational
  counts of long-latency replies and triggers with no reply.
- `assert_message_timestamp_parses` — reports rows whose source timestamp exists but
  failed to parse.

---

## Operational notes

- **Airbyte cursor (important):** Turn's `messages` / `message_statuses` cursor field
  `timestamp` is **Unix epoch**, so the connector needs `datetime_format: "%s"` and
  `cursor_datetime_formats: ["%s"]`. The configured `start_time` is ISO, so
  `start_datetime` needs its own `datetime_format: "%Y-%m-%dT%H:%M:%S.%fZ"`. A
  mis-set cursor doesn't error — it silently re-pulls all history every sync.
- **Type drift:** that cursor change re-typed `timestamp` from String to `Decimal`.
  The epoch parse is deliberately type-agnostic (`toFloat64OrNull(toString(...))`,
  seconds-vs-ms by magnitude) so it survives either.
- **Token rotation:** Turn tokens can't be renamed. Create a new one → update the
  **Airbyte Source config** → verify a sync → then delete the old. The Connector
  Builder's *Test* uses separate inputs, so a passing test with a **403** sync means
  the Source still holds the old token.
- **ClickHouse table cap:** the shared service enforces `max_table_num_to_throw`.
  Builds fail with `TOO_MANY_TABLES` when it's full — needs an admin to raise it.

---

## Validation

July outbound messages reconcile **exactly** with Turn's own Message Billing
("Insights Per Month" = 2,350). Reconciling against the source system is the
standard for validating changes here.

## Roadmap

Additional dashboard pages (Enrolment funnel, Clinical Assessment, Product Health
composite) are wireframed and will be populated once the JHOSS data model adds
county / cadre / assessment dimensions. APH shows zero until its flows are ingested.
