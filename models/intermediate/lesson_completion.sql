-- ============================================================
-- lesson_completion  (intermediate)
-- Purpose : Single source of truth for lesson completion. All completion metrics
--           (mini_module, module, progression, contact progress) read from here.
-- Grain   : One row per (module, mini_module, contact).
-- Logic   : Completion is measured PER raw flow (package), then rolled up as
--           "completed if ANY deployed variant of the lesson was finished." This
--           avoids the question-union problem where merging variant flows made
--           completion unattainable.
-- ============================================================

{{ config(order_by='(module_name, mini_module)') }}

with src as (
    select *
    from {{ ref('module_responses') }}
    where mini_module is not null
      and contact_id is not null
      and contact_id != ''
),
pkg_questions as (                       -- questions per raw flow (package)
    select package_id, uniqExact(question_key) as total_q
    from src group by package_id
),
contact_pkg as (
    select module_name, mini_module, package_id, contact_id,
           uniqExact(question_key)  as answered_q,
           min(toDate(response_ts)) as start_date,
           max(toDate(response_ts)) as last_date
    from src group by module_name, mini_module, package_id, contact_id
),
pkg_flag as (                            -- did the contact complete THAT flow?
    select cp.module_name, cp.mini_module, cp.contact_id, cp.start_date,
           cp.answered_q >= pq.total_q as pkg_completed,
           if(cp.answered_q >= pq.total_q, cp.last_date, cast(null as Nullable(Date))) as pkg_done_on
    from contact_pkg cp
    inner join pkg_questions pq on cp.package_id = pq.package_id
)
select 
    {{ dbt_utils.generate_surrogate_key(['module_name', 'mini_module', 'contact_id']) }} as id,
                                  -- lesson complete if ANY variant flow completed
    module_name, mini_module, contact_id,
    min(start_date)     as start_date,
    max(pkg_completed)  as completed,
    if(max(pkg_completed) = 1, minIf(pkg_done_on, pkg_completed = 1), cast(null as Nullable(Date))) as complete_date
from pkg_flag
group by module_name, mini_module, contact_id