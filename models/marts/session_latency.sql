-- ============================================================
-- session_latency  (mart)
-- Purpose : Session-grain latency so Power BI can compute a TRUE median/percentile
--           over any selected period (averaging daily medians is not valid).
-- Grain   : One row per replied user trigger. No user identifiers (BI-safe).
-- Source  : int_delta_sessions, bounded by max_reply_window_seconds.
-- ============================================================

{{ config(order_by='day') }}

select
    id,
    day,
    latency_seconds
from {{ ref('int_delta_sessions') }}
where latency_seconds between 0 and {{ var('max_reply_window_seconds', 3600) }}
order by day asc