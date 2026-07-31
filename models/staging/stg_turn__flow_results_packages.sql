{{ config(order_by='id') }}
select
    id, type, attributes, _airbyte_extracted_at
from {{ source('turn', 'flow_results_packages') }}
order by _airbyte_extracted_at desc
limit 1 by id