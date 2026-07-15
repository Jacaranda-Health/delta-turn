{{ config(materialized='table', engine='MergeTree()',
          order_by='(user_key, event_ts)', settings={'allow_nullable_key': 1}) }}

with parsed as (
    select
        id as message_id,
        _vnd,
        contacts,
        `to`,
        -- epoch may be seconds (10-digit) or milliseconds (13-digit); normalise ms -> s
        toDateTime64(toUInt64OrNull(timestamp) / if(length(timestamp) >= 13, 1000, 1), 3) as event_ts
    from {{ ref('stg_turn__messages') }}
)
select
    message_id,
    if(_vnd IS NULL, 'inbound', 'outbound') as direction,
    -- inbound: `contacts` is a JSON ARRAY [{ "wa_id": "2547...", "profile": {...} }]
    --          -> take element 1, then key 'wa_id' (positional array + key on the object).
    -- outbound: `to` = recipient phone.
    -- Normalise both to digits-only so formatting differences never break matching.
    if(_vnd IS NULL,
       replaceRegexpAll(JSONExtractString(assumeNotNull(contacts), 1, 'wa_id'), '[^0-9]', ''),
       replaceRegexpAll(`to`, '[^0-9]', '')
    ) as user_key,
    event_ts,
    toDate(event_ts) as day
from parsed