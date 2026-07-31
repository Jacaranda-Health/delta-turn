-- ============================================================
-- module_progression_daily  (mart)
-- Purpose : Distribution of contacts by number of lessons completed, per module
--           (powers the progression funnel/histogram).
-- Grain   : One row per (module, lessons_completed).
-- Source  : module_progression.
-- ============================================================

{{ config(order_by='(module_name, lessons_completed)') }}

select
    id,
    module_name,
    lessons_completed,
    contacts
from {{ ref('module_progression') }}
