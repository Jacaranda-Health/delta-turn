{{ config(engine='ReplacingMergeTree()', order_by='page_id', settings={'allow_nullable_key': 1}) }}
select
    page_id, data, links, _airbyte_extracted_at
from {{ source('turn', 'flow_results_responses') }}
order by _airbyte_extracted_at desc
limit 1 by page_id