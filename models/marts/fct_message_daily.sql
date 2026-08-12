-- ============================================================
-- fct_message_daily  (mart)
-- Purpose : Per-learner daily message counts + delivery status, so profile slicers
--           (dim_learner: learner_type / cadre / facility / county) can filter
--           message volume AND System Health (success rate, downtime). Relate
--           contact_id -> dim_learner and day -> dim_date.
-- Grain   : One row per (contact, day). contact_id may be null (unattributed).
-- Source  : int_message_events + int_message_status.
-- Note    : status_rank/any_error come via a LEFT JOIN; unmatched default to 0
--           (ClickHouse), which is the correct "no status" reading.
-- ============================================================

{{ config(materialized='table', engine='MergeTree', order_by='day',
          settings={'allow_nullable_key': 1}) }}

with events as (
    select
        e.contact_id,
        e.day,
        e.direction,
        e.message_id,
        coalesce(s.status_rank, 0) as status_rank,
        coalesce(s.any_error, 0)   as any_error
    from {{ ref('int_message_events') }} e
    left join {{ ref('int_message_status') }} s on e.message_id = s.message_id
),

daily as (
    select
        contact_id,
        day,
        countIf(direction = 'outbound')                      as outbound_msgs,
        countIf(direction = 'inbound')                       as inbound_msgs,
        countIf(direction = 'outbound' and status_rank >= 2) as delivered_msgs,  -- delivered or read
        countIf(direction = 'outbound' and status_rank >= 1) as sent_msgs,       -- at least sent
        countIf(direction = 'outbound' and any_error = 1)    as failed_msgs
    from events
    group by contact_id, day
)

select
    -- surrogate over a non-null key: contact_id is nullable (null = unattributed)
    {{ dbt_utils.generate_surrogate_key(['contact_key', 'day']) }} as id,
    contact_id,
    day,
    outbound_msgs,
    inbound_msgs,
    delivered_msgs,
    sent_msgs,
    failed_msgs
from (
    select *, coalesce(contact_id, '(unattributed)') as contact_key
    from daily
)
