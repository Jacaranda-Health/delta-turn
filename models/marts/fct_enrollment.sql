-- ============================================================
-- fct_enrollment  (mart)
-- Purpose : One row per learner with their enrolment day. Contact-grain fact so
--           profile slicers (dim_learner: cadre / county / facility) can filter
--           the enrolled-users KPI (Total Users). Relate contact_id -> dim_learner
--           and enroll_day -> dim_date.
-- Grain   : One row per contact.
-- Source  : int_flow_responses (first activity = enrolment).
-- ============================================================

{{ config(materialized='table', engine='MergeTree', order_by='contact_id') }}

select
    {{ dbt_utils.generate_surrogate_key(['contact_id']) }} as id,
    contact_id,
    min(toDate(response_ts)) as enroll_day
from {{ ref('int_flow_responses') }}
where contact_id is not null
group by contact_id
