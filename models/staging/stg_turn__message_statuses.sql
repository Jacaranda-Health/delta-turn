{{ config(materialized='table', engine='ReplacingMergeTree()',
          order_by='row_hash', settings={'allow_nullable_key': 1}) }}

select *
from {{ source('turn', 'message_statuses') }}
order by timestamp desc
limit 1 by row_hash