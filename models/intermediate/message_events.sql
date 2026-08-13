{{ config(order_by='(user_key, event_ts)') }}

with raw as (
    select
        id as message_id,
        _vnd,
        contacts,
        `to`,
        -- works whether Airbyte types this as String or Decimal/numeric
        toFloat64OrNull(toString(timestamp)) as ts_epoch
    from {{ ref('messages') }}
),

parsed as (
    select
        message_id,
        _vnd,
        contacts,
        `to`,
        -- epoch seconds vs milliseconds detected by magnitude (ms ≈ 1.7e12, s ≈ 1.7e9)
        toDateTime64(ts_epoch / if(ts_epoch > 100000000000, 1000, 1), 3) as event_ts
    from raw
),

events as (
    select
        {{ dbt_utils.generate_surrogate_key(['message_id']) }} as id,
        message_id,
        if(_vnd IS NULL, 'inbound', 'outbound') as direction,
        -- inbound: contacts is a JSON array [{"wa_id": "...", ...}] -> element 1, key wa_id
        -- outbound: `to` = recipient phone. Digits-only so both sides match.
        if(_vnd IS NULL,
           replaceRegexpAll(JSONExtractString(assumeNotNull(contacts), 1, 'wa_id'), '[^0-9]', ''),
           replaceRegexpAll(toString(`to`), '[^0-9]', '')
        ) as user_key,
        event_ts,
        toDate(event_ts) as day
    from parsed
),

-- Attribute each message to a learner by phone. Deduped to one row per phone so
-- the join can't fan out (inflate) message counts.
prof as (
    select
        replaceRegexpAll(phone, '[^0-9]', '') as phone_key,
        any(contact_id)  as contact_id,
        max(is_excluded) as is_excluded
    from {{ ref('contact_profile') }}
    where phone != ''
    group by phone_key
),

enriched as (
    select
        e.id, e.message_id, e.direction, e.user_key, e.event_ts, e.day,
        p.contact_id       as contact_id,
        p.is_excluded      as _is_excluded
    from events e
    left join prof p on e.user_key = p.phone_key
)

-- contact_id lets profile slicers (cadre/facility) filter message volume.
-- Tester exclusion gated OFF until go-live.
select
    id, message_id, direction, user_key, contact_id, event_ts, day
from enriched
{% if var('apply_contact_exclusions', false) %}
where coalesce(_is_excluded, false) = false
{% endif %}
