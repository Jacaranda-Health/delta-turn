-- must be empty: a negative latency would mean a backward/incorrect ASOF match
select * from {{ ref('delta_sessions') }} where latency_seconds < 0