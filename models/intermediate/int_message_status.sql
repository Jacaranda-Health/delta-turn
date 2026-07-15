{{ config(materialized='table', engine='MergeTree()',
          order_by='message_id', settings={'allow_nullable_key': 1}) }}

select
    id as message_id,
    max(multiIf(status='read',3, status='delivered',2, status='sent',1, 0)) as status_rank,
    max(if(errors is not null and errors != '', 1, 0))                       as any_error
from {{ ref('stg_turn__message_statuses') }}
where id is not null
group by id