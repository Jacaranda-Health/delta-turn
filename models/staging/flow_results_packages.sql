{{ config(order_by='id') }}
-- attributes is native JSON (attributes.title downstream)
select
    id,
    type,
    CAST(if(attributes IS NULL, '{}', toString(attributes)) AS JSON) as attributes,
    _airbyte_extracted_at
from {{ source('turn', 'flow_results_packages') }}
order by _airbyte_extracted_at desc
limit 1 by id
