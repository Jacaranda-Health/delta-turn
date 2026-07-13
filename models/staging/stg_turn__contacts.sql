{{ config(materialized='view') }}

select *
from {{ source('turn', 'contacts') }}
order by updated_at desc
limit 1 by id