# delta_turn

dbt project that transforms raw **Turn.io (WhatsApp)** data into clean, BI-ready
metrics for the **DELTA 2.0** provider-training programme (Kenya), served to a
Power BI dashboard.

Data flows: **Airbyte → ClickHouse (`turn_kenya`, raw) → dbt (`dev_munene`) → Power BI.**
All metric logic lives in dbt; Power BI reads final values only.

---

## The five Go-Live metrics

| Metric | Definition | Model |
|--------|-----------|-------|
| **Total enrolled users** | Distinct contacts who have initiated any DELTA flow (cumulative) | `mart_delta_kpis_daily.enrolled_cumulative` |
| **Message success rate** | Outbound messages reaching `delivered`/`read` ÷ sent | `mart_delta_kpis_daily.message_success_rate` |
| **Response latency** | Median seconds from a user trigger to DELTA's first reply | `mart_delta_kpis_daily.median_latency_seconds` |
| **Downtime rate** | Failed operations ÷ total operations | `mart_delta_kpis_daily.downtime_rate` |
| **Module completion rate** | Contacts who answered all questions in a module ÷ started, per module | `mart_module_completion_daily` |

Modules are rolled up to four canonical tracks: **PPH, Communication, RMC, Climate & Health.**

---

## Project structure

```
models/
  staging/       stg_turn__*        deduped 1:1 views/tables over raw Turn sources
  intermediate/  int_flow_responses, int_module_responses,
                 int_message_events, int_message_status, int_delta_sessions
  marts/         mart_delta_kpis_daily, mart_module_completion_daily
macros/          generate_schema_name (forces all models into dev_munene)
```

Lineage: `sources (turn_kenya) → staging → intermediate → marts`. Run `dbt docs generate && dbt docs serve` to browse the DAG and column docs.

---

## Setup

**Prerequisites:** Python venv with `dbt-clickhouse`, access to the ClickHouse
service, and a user with write on the `dev_munene` dev schema.

1. **Activate the environment**
   ```powershell
   C:\Users\<you>\Documents\dbt_test\dbt-env\Scripts\Activate.ps1
   cd delta_turn
   ```

2. **Set credentials** (per terminal session — never hardcode). The host must be the
   bare hostname (no `https://` — `secure: true` adds it).
   ```powershell
   $env:CLICKHOUSE_HOST='tplb1fkekn.eu-west-2.aws.clickhouse.cloud'
   $env:CLICKHOUSE_USER='<user>'
   $env:CLICKHOUSE_PASSWORD = Read-Host "CH password"
   ```

3. **`~/.dbt/profiles.yml`** (gitignored) — ClickHouse target, models build to `dev_munene`:
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
   ```

4. **Test the connection**
   ```powershell
   dbt debug
   ```

---

## Running

```powershell
dbt build                     # run all models + tests
dbt run --select staging      # or a subset
dbt test                      # data tests only
dbt docs generate             # build catalog + lineage
dbt docs serve --port 8081    # browse docs at http://localhost:8081
```

---

## Notes & conventions

- **Governance:** raw sources in `turn_kenya` are read-only; models only write to
  `dev_munene`. A `generate_schema_name` macro forces every model into `dev_munene`.
- **Dedup:** staging keeps the latest row per key (`limit 1 by <key>`); high-volume
  `messages` and `message_statuses` are `ReplacingMergeTree` tables, others are views.
- **Module completion** currently uses an "answered all questions" proxy, pending
  flow-level completion markers from the JHOSS model.
- **Power BI:** import mode over the ClickHouse connector; point at
  `dev_munene.mart_delta_kpis_daily` and `dev_munene.mart_module_completion_daily`.

## Roadmap

Additional pages (Enrolment funnel, Clinical Assessment, Product Health composite)
are wireframed and will be populated once the JHOSS data model adds county / cadre /
assessment dimensions.
