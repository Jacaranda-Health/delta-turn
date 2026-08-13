-- ============================================================
-- mini_module_completion  (metric)
-- Purpose : Daily lesson (mini-module) completion per canonical lesson.
-- Grain   : One row per (module, lesson, day).
-- Source  : lesson_completion, mini_module_map (seed).
-- Logic   : A contact completes a lesson if they finished ANY deployed variant
--           flow of it. Raw flow titles are mapped to canonical lesson names via
--           the crosswalk; the seed supplies lesson_order for dashboard sorting.
-- ============================================================

{{ config(order_by='(module_name, mini_module, day)') }}
with lc as (select * from {{ ref('lesson_completion') }}),
bounds as (select min(start_date) as s, max(start_date) as e from lc),
spine  as (select date_day as day from {{ ref('dates') }} cross join bounds where date_day between s and e),
minis  as (select distinct module_name, mini_module from lc)
select
    {{ dbt_utils.generate_surrogate_key(['module_name', 'mini_module', 'day']) }} as id,
    sp.day         as day,
    mm.module_name as module_name,
    mm.mini_module as mini_module,
    coalesce(mmap.lesson_title, replaceRegexpOne(mm.mini_module, '^[a-z]+_', '')) as lesson_label,
    coalesce(mmap.lesson_order, 999)                 as lesson_order,
    (multiIf(mm.module_name = 'PPH', 1, mm.module_name = 'APH', 2, mm.module_name = 'RMC', 3, mm.module_name = 'Communication', 4, 9) * 100
        + coalesce(mmap.lesson_order, 999))          as lesson_sort,
    countIf(lc.start_date <= sp.day)                          as cumulative_started,
    countIf(lc.completed = 1 and lc.complete_date <= sp.day)  as cumulative_completed,
    coalesce(round(countIf(lc.completed = 1 and lc.complete_date <= sp.day)
          / nullIf(countIf(lc.start_date <= sp.day), 0), 3), 0) as completion_rate
from spine sp
cross join minis mm
left join lc   on lc.module_name = mm.module_name and lc.mini_module = mm.mini_module
left join {{ ref('mini_module_map') }} mmap on mm.module_name = mmap.module_name and mm.mini_module = mmap.mini_module
group by sp.day, mm.module_name, mm.mini_module, mmap.lesson_title, mmap.lesson_order
order by mm.module_name, mmap.lesson_order, sp.day
