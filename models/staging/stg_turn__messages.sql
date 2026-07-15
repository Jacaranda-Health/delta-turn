{{ config(engine='ReplacingMergeTree()', order_by='id', settings={'allow_nullable_key': 1}) }}
select
    id, `to`, `from`, _vnd, text, type, contacts, recipient, timestamp, interactive, recipient_type, _airbyte_extracted_at
from {{ source('turn', 'messages') }}
order by timestamp desc
limit 1 by id