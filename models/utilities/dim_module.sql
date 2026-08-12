{{ config(materialized='table', engine='MergeTree', order_by='module_name') }}

-- Module dimension: one row per canonical module that has data.
-- Shared filter dimension so a single Module slicer cross-filters every
-- module-grained fact (module_completion_daily, mini_module_completion_daily,
-- module_progression_daily) without fact-to-fact relationships or ambiguous
-- paths through dim_date.
-- module_order gives the canonical module sequence for BI (sort module_name by it);
-- matches the module rank used in lesson_sort.
select distinct
    module_name,
    multiIf(
        module_name = 'PPH',           1,
        module_name = 'APH',           2,
        module_name = 'RMC',           3,
        module_name = 'Communication', 4,
        9
    ) as module_order
from {{ ref('int_lesson_completion') }}
