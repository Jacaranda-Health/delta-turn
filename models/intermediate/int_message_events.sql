{{ config(order_by='(user_key, event_ts)') }}

with raw as (
    select
        id as message_id,
        _vnd,
        contacts,
        `to`,
        -- works whether Airbyte types this as String or Decimal/numeric
        toFloat64OrNull(toString(timestamp)) as ts_epoch
    from {{ ref('stg_turn__messages') }}
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
)

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