-- ============================================================
-- contact_module_progress  (metric)
-- Purpose : Per-contact progress within each module — lessons started vs finished,
--           plus whether the contact completed the module's post-test. Contact
--           grain, so BI can slice module completion by profile (cadre/facility).
-- Grain   : One row per (module, contact).
-- Source  : lesson_completion.
-- ============================================================

{{ config(order_by='(module_name)') }}
select
    {{ dbt_utils.generate_surrogate_key(['module_name', 'contact_id']) }} as id,
    module_name,
    contact_id,
    uniqExact(mini_module)                             as lessons_started,
    uniqExactIf(mini_module, completed = 1)            as lessons_completed,
    maxIf(completed, mini_module ILIKE '%post_test%')  as posttest_completed
from {{ ref('lesson_completion') }}
group by module_name, contact_id
