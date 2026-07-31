-- ============================================================
-- module_completion_daily  (mart)
-- Purpose : BI-ready daily module completion + progress per module.
-- Grain   : One row per module per day.
-- Source  : module_completion.
-- ============================================================

select 
id,
day, module_name, cumulative_started, cumulative_completed, completion_rate
,module_progress, avg_lessons_completed, total_lessons
from {{ ref('module_completion') }}