{{ config(materialized='view') }}

select *
from {{ source('turn', 'flow_results_packages') }}
order by _airbyte_extracted_at desc
limit 1 by id