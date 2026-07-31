{{ config(order_by='row_hash') }}
select
    id, status, errors, row_hash, timestamp, recipient_id, pricing, conversation, _airbyte_extracted_at
from {{ source('turn', 'message_statuses') }}
order by timestamp desc
limit 1 by row_hash