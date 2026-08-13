{{ config(order_by='page_id') }}
-- data is native JSON (data.attributes.responses[] downstream)
select
    page_id,
    CAST(if(data IS NULL, '{}', toString(data)) AS JSON) as data,
    links,
    _airbyte_extracted_at
from {{ source('turn', 'flow_results_responses') }}
order by _airbyte_extracted_at desc
limit 1 by page_id
