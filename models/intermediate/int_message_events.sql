{{ config(materialized='table', engine='MergeTree()',
          order_by='(user_key, event_ts)', settings={'allow_nullable_key': 1}) }}

select
    id as message_id,
    if(JSONExtractString(toString(_vnd), 'v1', 'direction') = 'outbound', 'outbound', 'inbound') as direction,
    if(JSONExtractString(toString(_vnd), 'v1', 'direction') = 'outbound', recipient, contacts)    as user_key,
    toDateTime(toUInt32OrNull(timestamp))                as event_ts,
    toDate(toDateTime(toUInt32OrNull(timestamp)))        as day
from {{ ref('stg_turn__messages') }}