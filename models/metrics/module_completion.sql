-- ============================================================
-- module_completion  (metric)
-- Purpose : Daily module completion + progress per canonical module.
-- Grain   : One row per module per day.
-- Source  : lesson_completion, dates.
-- Logic   : posttest_completion_rate = contacts who completed the module's POST-TEST
--                              ÷ started. HEADLINE "module completed" metric shown to
--                              stakeholders (finishing the terminal assessment =
--                              finishing the course).
--           completion_rate  = contacts who completed ALL of a module's active
--                              lessons ÷ started (strict all-or-nothing; retained as
--                              a rigorous secondary measure).
--           module_progress  = avg fraction of a module's lessons a started
--                              contact has completed (continuous momentum measure).
-- Notes   : total_lessons counts active (has-data) lessons, so undeployed lessons
--            don't make completion impossible-by-construction. The post-test lesson
--            is identified by mini_module matching '%post_test%'.
-- ============================================================

with lc as (select * from {{ ref('lesson_completion') }}),
module_lessons as (select module_name, uniqExact(mini_module) as total_lessons from lc group by module_name),
posttest as (                          -- when each contact finished the module's post-test
    select module_name, contact_id,
           minIf(complete_date, completed = 1) as pt_complete_date
    from lc
    where mini_module ILIKE '%post_test%'
    group by module_name, contact_id
),
bounds as (select min(start_date) as s, max(start_date) as e from lc),
spine  as (select date_day as day from {{ ref('dates') }} cross join bounds where date_day between s and e),
contact_day as (
    select sp.day, lc.module_name, lc.contact_id,
           uniqExactIf(lc.mini_module, lc.completed = 1 and lc.complete_date <= sp.day) as lessons_done
    from spine sp inner join lc on lc.start_date <= sp.day
    group by sp.day, lc.module_name, lc.contact_id
)
select
    {{ dbt_utils.generate_surrogate_key(['cd.module_name', 'cd.day']) }} as id,
    cd.day          as day,
    cd.module_name  as module_name,
    count()                                              as cumulative_started,
    -- HEADLINE: completed the module's post-test
    countIf(pt.pt_complete_date is not null and pt.pt_complete_date <= cd.day)                                     as posttest_completed,
    coalesce(round(countIf(pt.pt_complete_date is not null and pt.pt_complete_date <= cd.day)/nullIf(count(),0),3),0) as posttest_completion_rate,
    -- STRICT: completed every active lesson
    countIf(cd.lessons_done >= ml.total_lessons)         as cumulative_completed,
    coalesce(round(countIf(cd.lessons_done >= ml.total_lessons)/nullIf(count(),0),3),0) as completion_rate,
    round(avg(cd.lessons_done / ml.total_lessons), 3)    as module_progress,
    round(avg(cd.lessons_done), 2)                       as avg_lessons_completed,
    max(ml.total_lessons)                                as total_lessons
from contact_day cd
inner join module_lessons ml on cd.module_name = ml.module_name
left join posttest      pt on cd.module_name = pt.module_name and cd.contact_id = pt.contact_id
group by cd.day, cd.module_name
order by cd.module_name, cd.day
