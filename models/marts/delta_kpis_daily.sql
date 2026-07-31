-- ============================================================
-- delta_kpis_daily  (mart)
-- Purpose : BI-ready daily KPIs for the Go-Live dashboard. Power BI reads this.
-- Grain   : One row per calendar day.
-- Source  : daily_kpis (final select only — marts do no aggregation).
-- ============================================================

select
    id,
    day,
    enrolled_cumulative,
    outbound_msgs,
    --message_success_rate,## calculating this in dax
    failed_msgs,
    --downtime_rate,## calculating this in dax
    median_latency_seconds,
    delivered_msgs,
    sent_msgs
from {{ ref('daily_kpis') }}