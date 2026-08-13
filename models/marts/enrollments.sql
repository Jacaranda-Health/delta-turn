-- ============================================================
-- enrollments  (mart)
-- Purpose : One row per learner with their enrolment day. Contact-grain fact so
--           profile slicers (learners: cadre / county / facility) can filter
--           the enrolled-users KPI (Total Users). Relate contact_id -> learners
--           and enroll_day -> dates.
-- Grain   : One row per contact.
-- Source  : flow_responses (first activity = enrolment).
-- ============================================================

{{ config(materialized='table', engine='MergeTree', order_by='contact_id') }}

select
    {{ dbt_utils.generate_surrogate_key(['contact_id']) }} as id,
    contact_id,
    min(toDate(response_ts)) as enroll_day
from {{ ref('flow_responses') }}
where contact_id is not null
group by contact_id
