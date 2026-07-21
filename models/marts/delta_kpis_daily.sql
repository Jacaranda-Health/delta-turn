{{ config(materialized='table') }}

select
    day,
    enrolled_cumulative,
    outbound_msgs,
    message_success_rate,
    failed_msgs,
    downtime_rate,
    median_latency_seconds
from {{ ref('daily_kpis') }}