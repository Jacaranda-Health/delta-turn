-- ============================================================
-- learner_module_progress  (mart)
-- Purpose : BI-ready per-learner module progress. Relate to dim_learner
--           (contact_id) and dim_module (module_name) for cadre / facility /
--           county cuts of lessons started/completed and post-test completion.
-- Grain   : One row per (module, contact).
-- Source  : contact_module_progress.
-- ============================================================

select
    id,
    contact_id,
    module_name,
    lessons_started,
    lessons_completed,
    posttest_completed
from {{ ref('contact_module_progress') }}
