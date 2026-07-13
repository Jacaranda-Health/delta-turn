{{ config(materialized='table', engine='ReplacingMergeTree()',
          order_by='id', settings={'allow_nullable_key': 1}) }}

select *
from {{ source('turn', 'messages') }}
order by timestamp desc
limit 1 by id