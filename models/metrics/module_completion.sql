-- ============================================================
-- module_completion  (metric)
-- Purpose : Daily module completion + progress per canonical module.
-- Grain   : One row per module per day.
-- Source  : int_lesson_completion, dim_date.
-- Logic   : completion_rate  = contacts who completed ALL of a module's active
--                              lessons ÷ started (strict, all-or-nothing).
--           module_progress  = avg fraction of a module's lessons a started
--                              contact has completed (continuous momentum measure).
-- Notes   : total_lessons counts active (has-data) lessons, so undeployed lessons
--           don't make completion impossible-by-construction.
-- ============================================================

with lc as (select * from {{ ref('int_lesson_completion') }}),
module_lessons as (select module_name, uniqExact(mini_module) as total_lessons from lc group by module_name),
bounds as (select min(start_date) as s, max(start_date) as e from lc),
spine  as (select date_day as day from {{ ref('dim_date') }} cross join bounds where date_day between s and e),
contact_day as (
    select sp.day, lc.module_name, lc.contact_id,
           uniqExactIf(lc.mini_module, lc.completed = 1 and lc.complete_date <= sp.day) as lessons_done
    from spine sp inner join lc on lc.start_date <= sp.day
    group by sp.day, lc.module_name, lc.contact_id
)
select
    {{ dbt_utils.generate_surrogate_key(['module_name', 'day']) }} as id,
    cd.day, cd.module_name,
    count()                                              as cumulative_started,
    countIf(cd.lessons_done >= ml.total_lessons)         as cumulative_completed,
    coalesce(round(countIf(cd.lessons_done >= ml.total_lessons)/nullIf(count(),0),3),0) as completion_rate,
    round(avg(cd.lessons_done / ml.total_lessons), 3)    as module_progress,
    round(avg(cd.lessons_done), 2)                       as avg_lessons_completed,
    max(ml.total_lessons)                                as total_lessons
from contact_day cd inner join module_lessons ml on cd.module_name = ml.module_name
group by cd.day, cd.module_name
order by cd.module_name, cd.day