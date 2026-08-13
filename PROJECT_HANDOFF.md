# DELTA 2.0 — Project Handoff

_Transfer document for continuing this work in a new session/account. Last updated: 2026-08-13._

## 1. What this project is

DELTA 2.0 is a **maternal-health provider-training analytics pipeline + Power BI dashboard** for **Jacaranda Health** (Kenya). Health providers (nurses, clinical officers, medical officers, etc.) are trained over **WhatsApp**, delivered through **Turn.io**. Training is organised into **4 modules** — **PPH** (postpartum haemorrhage), **APH** (antepartum haemorrhage), **RMC** (respectful maternity care), and **Communication** — each with a pretest, several mini-modules/lessons, and a post-test. The dashboard reports enrolment, module/lesson progress and completion, message volume, response latency, and system health, sliceable by learner attributes (cadre, county, facility) and a Live/Test toggle.

Go-live was **2026-08-11**. The dashboard has been shared internally (and with the Ona team) on Slack for feedback; current readings are still partly test data.

## 2. Stack & data flow

```
Turn.io (WhatsApp)  →  Airbyte  →  ClickHouse (raw)  →  dbt  →  ClickHouse (models)  →  Power BI
```

- **Raw schema:** `turn_kenya` (Airbyte-synced Turn tables; physical tables are prefixed, e.g. `turn_kenya.ciqyuq_contacts`). Declared as dbt sources under source name **`turn`**.
- **Model schema:** **`dev_munene`** — every model is forced into this schema by `macros/generate_schema_name.sql` (custom override), regardless of folder.
- **Warehouse:** ClickHouse Cloud — `https://tplb1fkekn.eu-west-2.aws.clickhouse.cloud:8443`.
- **dbt:** 1.11.11 with **dbt-clickhouse** 1.10.0. Package dep: `dbt_utils` (surrogate keys, date spine). Profile name `delta_turn` (credentials live in the user's `~/.dbt/profiles.yml`, **not** in this sandbox — builds run on the user's machine).
- **BI:** Power BI (star schema; facts relate to dims on `contact_id`, `day`/`date_day`, `module_name`).

> Note: dbt is **not** installed in the assistant sandbox. All `dbt build` / SQL validation is run by the user, who pastes results back.

## 3. Repository layout & model inventory

Config is kept **DRY in `dbt_project.yml`** (materialization/engine/settings there, not per-model). Vars:

| var | value | meaning |
|---|---|---|
| `max_reply_window_seconds` | 3600 | inbound→outbound reply cap for latency |
| `apply_contact_exclusions` | `false` | exclusion enforcement switch — OFF during test phase so the dashboard stays populated; flip at go-live |
| `go_live_date` | `2026-08-11` | a "Live" learner = non-test contact enrolled on/after this date |

Engines: **staging = ReplacingMergeTree** (deduped); intermediate/metrics/marts/utilities = **MergeTree**. Global `allow_nullable_key: 1`.

**Naming convention (important):** model names carry **no `dim_`/`fct_`/`int_`/`stg_` prefixes** — plain business nouns, plural for dimensions. This was an explicit stakeholder-facing requirement (prefixes leaked dbt-layer jargon into Power BI). A model may share a name with its source (`contacts` model over `source('turn','contacts')`); dbt namespaces `ref` vs `source`, so that's fine.

### Staging (`models/staging/`) — deduped, **native-JSON** tables over raw Turn sources
- `contacts` — `details` is a native `JSON` column
- `messages` — `contacts` kept as **String** (top-level JSON array; see §6)
- `message_statuses`
- `flow_results_packages` — `attributes` native `JSON`
- `flow_results_responses` — `data` native `JSON`

### Intermediate (`models/intermediate/`)
- **`contact_profile`** — ⚠️ **RESTRICTED / PII.** The only model holding phone + names. One row per contact; parses `details` via dot notation; derives `cadre_norm`, `county`, `facility`, `is_tester`, `is_excluded`, `opted_in`. **Do not expose to Power BI.**
- `flow_responses` — unnests `data.attributes.responses[]` (native JSON array) into one row per response (timestamp, contact_id, question_key, answer).
- `module_responses` — classifies each response into module (PPH/APH/RMC/Communication) + mini_module/lesson via title matching.
- `message_events` — one row per message; direction (inbound/outbound), `user_key` (phone digits), attributed `contact_id`.
- `message_status` — rolled-up delivery status per message.
- `delta_sessions`, `lesson_completion` — session/lesson intermediates.

### Utilities / dimensions (`models/utilities/`) — **BI-facing**
- `dates` (was `dim_date`) — daily spine incl. `week_start`/`week_end`, `month`.
- `learners` (was `dim_learner`) — **BI-safe learner dimension, NO PII.** `learner_key`, `contact_id`, `cadre`, `county`, `facility`, `learning_path`, `enrolled_month`, `is_excluded`, and **`learner_type`** (Live/Test).
- `modules` (was `dim_module`) — `module_name` + `module_order` (PPH=1, APH=2, RMC=3, Communication=4).
- `months` — month spine.

### Marts (`models/marts/`)
- `daily_messages` (was `fct_message_daily`) — per-(contact, day) message counts + delivery status (delivered/sent/failed) + `is_post_golive` flag. Powers volume + System Health.
- `enrollments` (was `fct_enrollment`) — enrolment facts (contact grain).
- `learner_module_progress`, `learner_lesson_completion`, `module_completion_daily`, `mini_module_completion_daily`, `module_progression_daily`, `session_latency` (carries `contact_id`), `delta_kpis_daily` (day-grain KPI table).

### Metrics (`models/metrics/`)
- `daily_kpis`, `module_completion`, `mini_module_completion`, `module_progression`, `contact_module_progress` — aggregation logic; `lesson_sort = module_rank*100 + lesson_order` gives canonical lesson ordering.

### Seeds (`seeds/`)
- `cadre_map.csv` — maps raw cadre strings → the canonical 10 (Medical Officer, Clinical Officer, Nurse, Student Intern, Consultant, Paramedic, EMT, Pharmacist, System Tester, Other Cadre not listed).
- `mini_module_map.csv` — module_name, mini_module, lesson_order, lesson_title (curated display names preserving medical terms: PPH, AMSTL, 4Ts, D&A, Trauma-Informed, Person-Centred).
- `excluded_contacts.csv` — manual exclusion seed (placeholder row).

### Tests (`tests/`)
`assert_latency_non_negative`, `assert_latency_within_window`, `assert_message_timestamp_parses`, `assert_unmatched_inbound`.

## 4. Core business logic & conventions

- **Live vs Test toggle** — `learners.learner_type = 'Live'` iff **not excluded AND enrolled on/after `go_live_date` (Aug 11 2026)**; else `'Test'`. This bounds the *person*, not the message date. To restrict *message* volume to post-go-live, filter on `daily_messages.is_post_golive` or apply a **page-level `dates[date_day] >= 2026-08-11`** filter in Power BI (the chosen approach). A Live learner's phone can still carry pre-enrolment message history — that's why a date filter is needed alongside the toggle.
- **Exclusions** — `contact_profile.is_excluded = is_tester OR contact_id IN excluded_contacts seed`. `is_tester` matches `SYSTEM TESTER` across all cadre fields. Enforcement is **gated OFF** (`apply_contact_exclusions=false`) so the dashboard stays populated during the test phase; flip to `true` at go-live.
- **Cadre/county cleanup** — the enrolment form migrated to new fields **`provider_cadre`** (title-case) and **`county_name`**; the pipeline prefers these, then falls back to legacy `cadre`/`cadre_1`/`county`. Values are trimmed/uppercased/de-underscored, then mapped to canonical labels via `cadre_map`; unmapped-but-present → "Other Cadre not listed"; `'COUNTY NOT LISTED'` placeholder is ignored.
- **Canonical ordering** — modules via `modules.module_order`; lessons via `lesson_sort`. Power BI "Sort by column" fails on repeating labels, so a numeric sort column is used (and a **Matrix** visual with `module_order`/`lesson_sort` for the drill-down module→lesson view).
- **Module completion** is post-test-based.
- **PII isolation** — phone/name live **only** in `contact_profile`. `learners` is the BI-safe dimension. Never surface `contact_profile` to Power BI; restrict grants on its schema.

## 5. Just-completed work (this session)

Two refactors, both **done in code**, pending the user's build + Power BI re-map:

1. **Native JSON refactor** — staging now emits native `JSON` columns (`CAST(if(col IS NULL,'{}',toString(col)) AS JSON)`); downstream uses dot notation instead of `JSONExtract*`. Validated on the live instance (opted_in=115, inbound=12,207, 130 contacts, 21,405 responses — nothing dropped). Only **one** `JSONExtract` remains by design: `message_events` inbound `wa_id`, because `messages.contacts` is a top-level JSON **array** (kept String).
2. **De-prefixing rename** — 18 models renamed to drop `stg_/int_/dim_/fct_`; every `ref()`, yml `name:`, config, comment, and README updated via a whole-word sweep. Source definitions and raw tables untouched.

## 6. ClickHouse / dbt gotchas (hard-won — read before editing)

- **LEFT JOIN nulls:** unmatched rows get the column **default** (`0`/`''`), **not NULL**. `joined_col IS NOT NULL` is always true. Use `col IN (SELECT …)` or test `!= ''`. (This bug once flagged all learners as excluded.)
- **Native `JSON` type is object-only.** A column whose value is a top-level **array** (`messages.contacts = [{…}]`) throws code 117 on insert to `JSON`. Options: type it `Array(JSON)` (null placeholder `'[]'`) for dot access, or keep `String` + one `JSONExtractString`. We kept `contacts` String.
  - Missing JSON key → `CAST(col.key AS String)` returns `''` (empty), not `'null'` — coalesce/`nullIf(...,'')` logic stays valid.
  - JSON boolean → `CAST(col.flag AS String) = 'true'` works.
  - Object array: `arrayJoin(CAST(data.attributes.responses AS Array(Array(String))))` then positional `resp[1]`, `resp[3]`, …
- **Ambiguous qualified columns:** `p.col` can become an output column literally named `p.col` across joins — always alias explicitly (`p.contact_id as contact_id`).
- **`generate_surrogate_key` on a nullable column** throws `CAST(NULL as String)` — coalesce to a sentinel first (`coalesce(contact_id,'(unattributed)')`).
- **Build only from the branch with the latest work.** Running `dbt build` off `main`/`docs` regenerates models from stale code and reverts DB tables, breaking the dashboard. Current working branch: **`feat/learner-profile`**.
- **PR cadence:** commit + push + PR per logical chunk; don't accumulate one giant bundle.
- **Editor clobber:** the local editor has occasionally saved stale buffers over disk mid-build — reload files before building.

## 7. Immediate next actions (open)

On the user's machine, from `feat/learner-profile`:
1. `dbt build` (full — the rename touched the ref graph everywhere).
2. **Drop 18 orphaned pre-rename tables** in `dev_munene` (old `int_*`/`stg_turn__*`/`dim_*`/`fct_*` names) — `dbt build` creates new-named tables but doesn't drop old ones.
3. **Power BI re-map** the 6 exposed tables + relationships: `dim_date→dates`, `dim_learner→learners`, `dim_module→modules`, `dim_month→months`, `fct_enrollment→enrollments`, `fct_message_daily→daily_messages`. Keys unchanged.
4. Commit both refactors (git detects the 18 renames) and push.

## 8. Parallel workstream — MENTORS ↔ DELTA learner linkage

Separate leadership initiative: linking **in-person** learners (MENTORS programme) with **virtual** (DELTA) learners via WhatsApp/Meta identifiers, anchored on a **Phone Number Registry** and a `user_id` anchor. Key finding (web-verified against Meta docs): **`wa_id` and BSUID both regenerate when a provider changes phone number**, and the `user_changed_number` webhook carries old→new — so neither is durable across a number change; the Phone Registry must reconcile. Deliverables in the DELTA docs folder: `MENTORS In-person_DELTA UUID Linkage 2026_v2.docx`, `MENTORS_linkage_ER.mermaid`, `MENTORS_learner_linkage_data_plan.md`. Recommendation included: nudge in-person learners to submit their WhatsApp numbers.

## 9. People / context

- **Denis (Njambanene / njukidenis47)** — data/analytics owner, does the dbt + Power BI work and runs all builds.
- **Kayla → Kat transition (June 2026):** Kayla departed (handled); Kat is confirmed successor. Child Health data-context meeting with Kayla is done. Risk: Kat doubling up until a DnA backfill hire is confirmed.
- Weekly Friday status report uses the **previous week's report** as its baseline (not task-file defaults).

## 10. Key reference files

- `README.md` — architecture overview (kept in sync with the new names).
- `dbt_project.yml` — vars + DRY engine/settings config.
- `macros/generate_schema_name.sql` — forces all models into `dev_munene`.
- `seeds/` — cadre_map, mini_module_map, excluded_contacts.
- DELTA docs folder — data dictionary (`DELTA_Data_Dictionary_v1.md`), Power BI dashboard docs, MENTORS linkage docs, sprint backlog.
