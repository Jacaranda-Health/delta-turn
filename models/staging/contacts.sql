{{ config(order_by='id') }}
-- details is a native JSON column so downstream can use dot notation (details.key)
select
    id,
    uuid,
    CAST(if(details IS NULL, '{}', toString(details)) AS JSON) as details,
    number_id,
    updated_at,
    inserted_at,
    _airbyte_extracted_at
from {{ source('turn', 'contacts') }}
order by updated_at desc
limit 1 by id
