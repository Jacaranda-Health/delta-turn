{{ config(materialized='table', engine='MergeTree', order_by='module_name') }}

-- Module dimension: one row per canonical module that has data.
-- Shared filter dimension so a single Module slicer cross-filters every
-- module-grained fact (module_completion_daily, mini_module_completion_daily,
-- module_progression_daily) without fact-to-fact relationships or ambiguous
-- paths through dim_date.
select distinct module_name
from {{ ref('int_lesson_completion') }}
