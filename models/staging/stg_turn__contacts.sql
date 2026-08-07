{{ config(order_by='id') }}
select
    id, uuid, details, number_id, updated_at, inserted_at, _airbyte_extracted_at
from {{ source('turn', 'contacts') }}
order by updated_at desc
limit 1 by id