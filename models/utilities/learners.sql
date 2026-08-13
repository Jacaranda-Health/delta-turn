{{ config(materialized='table', engine='MergeTree', order_by='contact_id') }}

-- ============================================================
-- learners  (dimension — BI-SAFE, NO PII)
-- Purpose : Learner dimension for Power BI. Relates to the facts on contact_id
--           (like modules / dates), enabling facility / county / cadre
--           slicers and exclusion of test accounts. Holds NO phone or names.
-- Grain   : One row per contact.
-- Source  : contact_profile (identifiers stripped here).
-- ============================================================

select
    {{ dbt_utils.generate_surrogate_key(['contact_id']) }} as learner_key,
    contact_id,
    cadre,
    county,
    facility_raw                  as facility,
    learning_path,
    toStartOfMonth(enrollment_at) as enrolled_month,
    is_excluded,
    -- Live/Test toggle: Live = a genuine learner (not test) enrolled ON/AFTER go-live.
    -- Testers, seed-excluded, and pre-go-live (test-phase) enrolments are all 'Test'.
    if(not is_excluded
       and toDate(enrollment_at) >= toDate('{{ var("go_live_date", "2026-08-11") }}'),
       'Live', 'Test')              as learner_type
from {{ ref('contact_profile') }}
