-- ============================================================
-- contact_module_progress  (metric)
-- Purpose : Per-contact progress within each module — how many lessons a user
--           has started vs finished. Feeds the "how many users finished how many
--           lessons" distribution.
-- Grain   : One row per (module, contact).
-- Source  : int_lesson_completion.
-- Logic   : lessons_started = distinct lessons the contact touched;
--           lessons_completed = distinct lessons the contact finished.
-- ============================================================

{{ config(order_by='(module_name)') }}
select
    {{ dbt_utils.generate_surrogate_key(['module_name', 'contact_id']) }} as id,
    module_name,
    contact_id,
    uniqExact(mini_module)                    as lessons_started,
    uniqExactIf(mini_module, completed = 1)   as lessons_completed
from {{ ref('int_lesson_completion') }}
group by module_name, contact_id
