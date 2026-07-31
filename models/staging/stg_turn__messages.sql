{{ config(order_by='id') }}
select
    id, `to`, `from`, _vnd, text, type, contacts, recipient, timestamp, interactive, recipient_type, _airbyte_extracted_at
from {{ source('turn', 'messages') }}
order by timestamp desc
limit 1 by id