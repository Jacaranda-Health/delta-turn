{{ config(materialized='view') }}

select *
from {{ source('turn', 'flow_results_responses') }}
order by _airbyte_extracted_at desc
limit 1 by page_id