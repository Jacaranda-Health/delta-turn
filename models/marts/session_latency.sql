{{ config(materialized='table', engine='MergeTree()', order_by='day',
          settings={'allow_nullable_key': 1}) }}

select
    day,
    latency_seconds
from {{ ref('int_delta_sessions') }}
where latency_seconds between 0 and {{ var('max_reply_window_seconds', 3600) }}
order by day asc