-- ============================================================
-- learner_lesson_completion  (mart)
-- Purpose : Per-learner lesson completion. Contact-grain so the Lesson Completion
--           table can be sliced by profile (cadre / facility / county) via
--           dim_learner. Relate contact_id -> dim_learner, module_name -> dim_module.
-- Grain   : One row per (module, lesson, contact).
-- Source  : int_lesson_completion.
-- ============================================================

select
    lc.id,
    lc.contact_id,
    lc.module_name,
    lc.mini_module,
    coalesce(mmap.lesson_title, replaceRegexpOne(lc.mini_module, '^[a-z]+_', '')) as lesson_label,
    (multiIf(lc.module_name = 'PPH', 1, lc.module_name = 'APH', 2, lc.module_name = 'RMC', 3, lc.module_name = 'Communication', 4, 9) * 100
        + coalesce(mmap.lesson_order, 999))          as lesson_sort,
    lc.completed
from {{ ref('int_lesson_completion') }} lc
left join {{ ref('mini_module_map') }} mmap
    on lc.module_name = mmap.module_name and lc.mini_module = mmap.mini_module
