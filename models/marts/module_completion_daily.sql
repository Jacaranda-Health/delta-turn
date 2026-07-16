{{ config(materialized='table', engine='MergeTree()',
          order_by='(module_name, day)',
          settings={'allow_nullable_key': 1}) }}

with module_qcount as (
    select module_name, uniqExact(question_key) as total_questions
    from {{ ref('int_module_responses') }}
    group by module_name
),

contact_module as (
    select
        module_name,
        contact_id,
        min(toDate(response_ts)) as start_date,
        max(toDate(response_ts)) as last_date,
        uniqExact(question_key)  as answered_questions
    from {{ ref('int_module_responses') }}
    group by module_name, contact_id
),

flagged as (
    select
        cm.module_name,
        cm.contact_id,
        cm.start_date,
        cm.answered_questions >= mq.total_questions as completed,
        if(cm.answered_questions >= mq.total_questions, cm.last_date, null) as complete_date
    from contact_module cm
    inner join module_qcount mq on cm.module_name = mq.module_name
),

spine   as (select distinct toDate(response_ts) as day from {{ ref('int_module_responses') }}),
modules as (select distinct module_name          from {{ ref('int_module_responses') }})

select
    s.day                                                         as day,
    m.module_name                                                 as module_name,
    countIf(f.start_date <= s.day)                                as cumulative_started,
    countIf(f.completed and f.complete_date <= s.day)            as cumulative_completed,
    round(countIf(f.completed and f.complete_date <= s.day)
          / nullIf(countIf(f.start_date <= s.day), 0), 3)        as completion_rate
from spine s
cross join modules m
left join flagged f on f.module_name = m.module_name
group by s.day, m.module_name
order by m.module_name, s.day