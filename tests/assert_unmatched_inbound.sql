{{ config(severity='warn') }}
-- warn: inbound triggers with no DELTA reply (some expected; investigate if the count is high)
select * from {{ ref('int_delta_sessions') }} where out_ts is null