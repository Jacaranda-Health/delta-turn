{{ config(order_by='message_id') }}

-- Roll delivery statuses up to one row per message (furthest status reached).
-- message_id is derived in this inner scope FIRST so the surrogate key below
-- can hash it without the alias shadowing the raw `id` column.
with status_rolled as (
    select
        id as message_id,
        max(multiIf(status='read', 3, status='delivered', 2, status='sent', 1, 0)) as status_rank,
        max(if(errors is not null and errors != '', 1, 0))                          as any_error
    from {{ ref('message_statuses') }}
    where id is not null
    group by id
)

select
    {{ dbt_utils.generate_surrogate_key(['message_id']) }} as id,
    message_id,
    status_rank,
    any_error
from status_rolled