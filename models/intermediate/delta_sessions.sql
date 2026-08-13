{{ config(order_by='day') }}

with inbound as (
    select message_id, user_key, contact_id, event_ts as in_ts
    from {{ ref('message_events') }}
    where direction = 'inbound' and user_key != '' and event_ts is not null
),
outbound as (
    select user_key, event_ts as out_ts
    from {{ ref('message_events') }}
    where direction = 'outbound' and user_key != '' and event_ts is not null
)
select
    {{ dbt_utils.generate_surrogate_key(['message_id']) }} as id,
    toDate(i.in_ts) as day,
    i.user_key,
    i.contact_id,
    i.in_ts,
    o.out_ts,
    if(o.out_ts is null, null, dateDiff('second', i.in_ts, o.out_ts)) as latency_seconds
from inbound i
asof left join outbound o
  on i.user_key = o.user_key
 and i.in_ts <= o.out_ts        -- forward lookup: first outbound AT/AFTER the trigger
