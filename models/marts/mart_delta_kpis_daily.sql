{{ config(materialized='table', engine='MergeTree()',
          order_by='day', settings={'allow_nullable_key': 1}) }}

with enroll as (
    select contact_id, min(toDate(response_ts)) as enroll_day
    from {{ ref('int_flow_responses') }}
    group by contact_id
),
out_msg as (
    select e.day, e.message_id,
        coalesce(s.status_rank, 0) as status_rank,
        coalesce(s.any_error, 0)   as any_error
    from {{ ref('int_message_events') }} e
    left join {{ ref('int_message_status') }} s on e.message_id = s.message_id
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
    from {{ ref('int_delta_sessions') }}
    where latency_seconds between 0 and 86400
    group by day
),
spine as (
    select day from msg_daily
    union distinct select enroll_day from enroll
    union distinct select day from lat_daily
),
enroll_cum as (
    select sp.day, uniqExact(e.contact_id) as enrolled_cumulative
    from spine sp
    inner join enroll e on e.enroll_day <= sp.day
    group by sp.day
)
select
    sp.day as day,
    ec.enrolled_cumulative,
    md.outbound_msgs,
    round(md.delivered_msgs / nullIf(md.sent_msgs, 0), 3)  as message_success_rate,
    md.failed_msgs,
    round(md.failed_msgs / nullIf(md.outbound_msgs, 0), 3) as downtime_rate,
    ld.median_latency_seconds
from spine sp
left join enroll_cum ec on sp.day = ec.day
left join msg_daily  md on sp.day = md.day
left join lat_daily  ld on sp.day = ld.day
order by sp.day