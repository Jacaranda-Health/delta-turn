{{ config(engine='ReplacingMergeTree()', order_by='row_hash', settings={'allow_nullable_key': 1}) }}
select
    id, status, errors, row_hash, timestamp, recipient_id, pricing, conversation, _airbyte_extracted_at
from {{ source('turn', 'message_statuses') }}
order by timestamp desc
limit 1 by row_hash