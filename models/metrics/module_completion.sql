{{ config(materialized='table', engine='MergeTree()', order_by='(module_name, day)',
          settings={'allow_nullable_key': 1}) }}

with module_qcount as (
    select module_name, uniqExact(question_key) as total_questions
    from {{ ref('int_module_responses') }}
    group by module_name
),
contact_module as (
    select module_name, contact_id,
        min(toDate(response_ts)) as start_date,
        max(toDate(response_ts)) as last_date,
        uniqExact(question_key)  as answered_questions
    from {{ ref('int_module_responses') }}
    group by module_name, contact_id
),
flagged as (
    select cm.module_name, cm.contact_id, cm.start_date,
        cm.answered_questions >= mq.total_questions as completed,
        if(cm.answered_questions >= mq.total_questions, cm.last_date, null) as complete_date
    from contact_module cm
    inner join module_qcount mq on cm.module_name = mq.module_name
),
bounds as (select min(start_date) as start_day, max(start_date) as end_day from flagged),
spine as (
    select d.date_day as day
    from {{ ref('dim_date') }} d
    cross join bounds b
    where d.date_day between b.start_day and b.end_day
),
modules as (select distinct module_name from {{ ref('int_module_responses') }})
select
    sp.day        as day,
    m.module_name as module_name,
    countIf(f.start_date <= sp.day)                             as cumulative_started,
    countIf(f.completed and f.complete_date <= sp.day)          as cumulative_completed,
    coalesce(
        round(countIf(f.completed and f.complete_date <= sp.day)
              / nullIf(countIf(f.start_date <= sp.day), 0), 3),
        0)                                                       as completion_rate
from spine sp
cross join modules m
left join flagged f on f.module_name = m.module_name
group by sp.day, m.module_name
order by m.module_name, sp.day