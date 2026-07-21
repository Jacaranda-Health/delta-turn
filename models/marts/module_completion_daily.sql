{{ config(materialized='table') }}

select
    day,
    module_name,
    cumulative_started,
    cumulative_completed,
    completion_rate
from {{ ref('module_completion') }}