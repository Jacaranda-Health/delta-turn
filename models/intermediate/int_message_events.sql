{{ config(materialized='table', engine='MergeTree()',
          order_by='(user_key, event_ts)', settings={'allow_nullable_key': 1}) }}

select
    id as message_id,
    if(_vnd IS NULL, 'inbound', 'outbound') as direction,
    if(_vnd IS NULL,
       JSONExtractString(assumeNotNull(contacts), 1, 'wa_id'),   -- inbound: user's wa_id
       `to`)                                                     -- outbound: user's phone
        as user_key,
    toDateTime(toUInt32OrNull(timestamp))         as event_ts,
    toDate(toDateTime(toUInt32OrNull(timestamp))) as day
from {{ ref('stg_turn__messages') }}