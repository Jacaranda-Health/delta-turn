-- must be empty: a negative latency would mean a backward/incorrect ASOF match
select * from {{ ref('int_delta_sessions') }} where latency_seconds < 0