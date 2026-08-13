{{ config(order_by='id') }}
-- contacts is a JSON *array* (e.g. [{"wa_id":"..."}]); ClickHouse JSON type
-- only accepts objects, so keep as String and parse downstream.
select
    id, `to`, `from`, _vnd, text, type,
    ifNull(toString(contacts), '[]') as contacts,
    recipient, timestamp, interactive, recipient_type, _airbyte_extracted_at
from {{ source('turn', 'messages') }}
order by timestamp desc
limit 1 by id
