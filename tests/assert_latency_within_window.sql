{{ config(severity='warn') }}
-- warn: replies matched beyond the session window (tune max_reply_window_seconds)
select * from {{ ref('delta_sessions') }}
where latency_seconds > {{ var('max_reply_window_seconds', 3600) }}