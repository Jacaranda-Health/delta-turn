{{ config(order_by='page_id') }}
select
    page_id, data, links, _airbyte_extracted_at
from {{ source('turn', 'flow_results_responses') }}
order by _airbyte_extracted_at desc
limit 1 by page_id