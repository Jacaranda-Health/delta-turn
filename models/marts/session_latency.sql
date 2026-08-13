-- ============================================================
-- session_latency  (mart)
-- Purpose : Session-grain latency so Power BI can compute a TRUE median/percentile
--           over any selected period (averaging daily medians is not valid). Now
--           carries contact_id so latency can be sliced by profile (cadre/facility)
--           via learners. Still no phone/name.
-- Grain   : One row per replied user trigger.
-- Source  : delta_sessions, bounded by max_reply_window_seconds.
-- ============================================================

{{ config(order_by='day') }}

select
    id,
    day,
    contact_id,
    latency_seconds
from {{ ref('delta_sessions') }}
where latency_seconds between 0 and {{ var('max_reply_window_seconds', 3600) }}
order by day asc
