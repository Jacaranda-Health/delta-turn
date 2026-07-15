{{ config(engine='ReplacingMergeTree()', order_by='id', settings={'allow_nullable_key': 1}) }}
select
    id, type, attributes, _airbyte_extracted_at
from {{ source('turn', 'flow_results_packages') }}
order by _airbyte_extracted_at desc
limit 1 by id