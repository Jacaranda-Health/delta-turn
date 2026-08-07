-- ============================================================
-- module_completion_daily  (mart)
-- Purpose : BI-ready daily module completion + progress per module.
-- Grain   : One row per module per day.
-- Source  : module_completion.
-- Note    : posttest_completion_rate is the headline "module completed" metric;
--           completion_rate is the strict all-lessons variant.
-- ============================================================

select
    id,
    day, module_name, cumulative_started,
    posttest_completed, posttest_completion_rate,
    cumulative_completed, completion_rate,
    module_progress, avg_lessons_completed, total_lessons
from {{ ref('module_completion') }}
