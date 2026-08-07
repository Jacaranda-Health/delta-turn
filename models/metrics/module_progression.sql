{{ config(order_by='(module_name, lessons_completed)') }}

with src as (
    select * from {{ ref('int_module_responses') }} where mini_module is not null
),
mini_questions as (
    select module_name, mini_module, uniqExact(question_key) as total_q
    from src group by module_name, mini_module
),
contact_mini as (
    select module_name, mini_module, contact_id, uniqExact(question_key) as answered_q
    from src group by module_name, mini_module, contact_id
),
contact_completed as (
    select cm.module_name, cm.contact_id,
           uniqExactIf(cm.mini_module, cm.answered_q >= mq.total_q) as lessons_completed
    from contact_mini cm
    inner join mini_questions mq
        on cm.module_name = mq.module_name and cm.mini_module = mq.mini_module
    group by cm.module_name, cm.contact_id
)
select
    {{ dbt_utils.generate_surrogate_key(['module_name', 'lessons_completed']) }} as id,
    module_name,
    lessons_completed,
    count() as contacts
from contact_completed
group by module_name, lessons_completed
order by module_name, lessons_completed