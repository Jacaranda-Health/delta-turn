{{ config(materialized='table', engine='MergeTree', order_by='contact_id') }}

-- ============================================================
-- dim_learner  (dimension — BI-SAFE, NO PII)
-- Purpose : Learner dimension for Power BI. Relates to the facts on contact_id
--           (like dim_module / dim_date), enabling facility / county / cadre
--           slicers and exclusion of test accounts. Holds NO phone or names.
-- Grain   : One row per contact.
-- Source  : int_contact_profile (identifiers stripped here).
-- ============================================================

select
    {{ dbt_utils.generate_surrogate_key(['contact_id']) }} as learner_key,
    contact_id,
    cadre,
    county,
    facility_raw                  as facility,
    learning_path,
    toStartOfMonth(enrollment_at) as enrolled_month,
    is_excluded
from {{ ref('int_contact_profile') }}
