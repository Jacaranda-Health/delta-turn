-- ============================================================
-- mini_module_completion_daily  (mart)
-- Purpose : BI-ready daily lesson (mini-module) completion.
-- Grain   : One row per (module, lesson, day).
-- Source  : mini_module_completion. Carries lesson_label + lesson_order for the UI.
-- ============================================================
select 
    id,
    day, module_name, mini_module, lesson_label, lesson_order, lesson_sort,
    cumulative_started, cumulative_completed, completion_rate
from {{ ref('mini_module_completion') }}