-- ============================================================
-- learner_lesson_completion  (mart)
-- Purpose : Per-learner lesson completion. Contact-grain so the Lesson Completion
--           table can be sliced by profile (cadre / facility / county) via
--           dim_learner. Relate contact_id -> dim_learner, module_name -> dim_module.
-- Grain   : One row per (module, lesson, contact).
-- Source  : int_lesson_completion.
-- ============================================================

select
    id,
    contact_id,
    module_name,
    mini_module,
    replaceRegexpOne(mini_module, '^[a-z]+_', '') as lesson_label,
    completed
from {{ ref('int_lesson_completion') }}
