{{ config(engine='ReplacingMergeTree()', order_by='id', settings={'allow_nullable_key': 1}) }}
select
    id, uuid, details, number_id, updated_at, inserted_at, _airbyte_extracted_at
from {{ source('turn', 'contacts') }}
order by updated_at desc
limit 1 by id