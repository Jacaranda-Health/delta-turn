{{ config(order_by='(package_id, response_ts)') }}

with raw as (
    select CAST(toString(data) AS JSON) as data     -- native JSON
    from {{ source('turn', 'flow_results_responses') }}
    where data is not null
),

pages as (
    select
        CAST(data.id AS String)                                 as package_id,
        CAST(data.attributes.responses AS Array(Array(String))) as responses
    from raw
    where length(data.attributes.responses) > 0
),

exploded as (
    select package_id, arrayJoin(responses) as resp
    from pages
),

responses_flat as (
    select
        {{ dbt_utils.generate_surrogate_key(['package_id', 'response_row_id']) }} as id,
        package_id,
        -- Turn Flow-Results response tuple (positional per the data-package spec):
        --   [1]=timestamp  [2]=row_id  [3]=contact_id  [4]=session_id
        --   [5]=question_key  [6]=answer  [7]=metadata
        parseDateTime64BestEffortOrNull(resp[1]) as response_ts,
        resp[2] as response_row_id,
        -- contact_id: clean numeric string so it matches contacts.id / learners
        nullIf(replaceRegexpAll(resp[3], '[^0-9]', ''), '') as contact_id,
        resp[4] as session_id,
        resp[5] as question_key,
        resp[6] as answer_value
    from exploded
)

-- Drop excluded contacts at the earliest point carrying contact_id (gated OFF until go-live).
select *
from responses_flat
{% if var('apply_contact_exclusions', false) %}
where contact_id not in (
    select contact_id from {{ ref('contact_profile') }} where is_excluded
)
{% endif %}
