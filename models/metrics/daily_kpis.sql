-- ============================================================
-- daily_kpis  (metric)
-- Purpose : Daily product & engagement KPIs — enrolled users, message success,
--           downtime, response latency.
-- Grain   : One row per calendar day (gap-free via dates spine).
-- Source  : flow_responses, message_events, message_status,
--           delta_sessions, dates.
-- Notes   : Counts are 0-filled on quiet days; rates & latency are NULL (not 0),
--           since a rate/median of no activity is undefined. Rates are 0–1 ratios.
-- ============================================================

{{ config(order_by='day') }}

with enroll as (
    select contact_id, min(toDate(response_ts)) as enroll_day
    from {{ ref('flow_responses') }}
    group by contact_id
),
out_msg as (
    select e.day, e.message_id,
        coalesce(s.status_rank, 0) as status_rank,
        coalesce(s.any_error, 0)   as any_error
    from {{ ref('message_events') }} e
    left join {{ ref('message_status') }} s on e.message_id = s.message_id
    where e.direction = 'outbound'
),
msg_daily as (
    select day,
        count(*)                as outbound_msgs,
        countIf(status_rank>=2) as delivered_msgs,
        countIf(status_rank>=1) as sent_msgs,
        countIf(any_error=1)    as failed_msgs
    from out_msg group by day
),
lat_daily as (
    select day, round(median(latency_seconds)) as median_latency_seconds
    from {{ ref('delta_sessions') }}
    where latency_seconds between 0 and {{ var('max_reply_window_seconds', 3600) }}
    group by day
),
bounds as (
    select
        least((select min(enroll_day) from enroll), (select min(day) from msg_daily))    as start_day,
        greatest((select max(enroll_day) from enroll), (select max(day) from msg_daily)) as end_day
),
spine as (
    select d.date_day as day
    from {{ ref('dates') }} d
    cross join bounds b
    where d.date_day between b.start_day and b.end_day
),
enroll_cum as (
    select sp.day, uniqExact(e.contact_id) as enrolled_cumulative
    from spine sp
    inner join enroll e on e.enroll_day <= sp.day
    group by sp.day
)
select
    {{ dbt_utils.generate_surrogate_key(['day']) }} as id,
    sp.day                                                              as day,
    coalesce(ec.enrolled_cumulative, 0)                                 as enrolled_cumulative,
    coalesce(md.outbound_msgs, 0)                                       as outbound_msgs,
    cast(round(md.delivered_msgs / nullIf(md.sent_msgs, 0), 3) as Nullable(Float32))  as message_success_rate,
    coalesce(md.failed_msgs, 0)                                         as failed_msgs,
    cast(round(md.failed_msgs / nullIf(md.outbound_msgs, 0), 3) as Nullable(Float32)) as downtime_rate,
    cast(ld.median_latency_seconds as Nullable(Float32))               as median_latency_seconds,
    coalesce(md.delivered_msgs, 0)  as delivered_msgs,
    coalesce(md.sent_msgs, 0)       as sent_msgs
from spine sp
left join enroll_cum ec on sp.day = ec.day
left join msg_daily  md on sp.day = md.day
left join lat_daily  ld on sp.day = ld.day
order by sp.day