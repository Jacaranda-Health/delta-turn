{{ config(order_by='(package_id, response_ts)') }}

with raw as (
    select toString(assumeNotNull(data)) as data_str   -- non-null String (avoids Array-in-Nullable)
    from {{ source('turn', 'flow_results_responses') }}
    where data is not null                              -- explicit null filter first
),

pages as (
    select
        JSONExtractString(data_str, 'id') as package_id,
        JSONExtractArrayRaw(data_str, 'attributes', 'responses') as responses
    from raw
    where JSONLength(data_str, 'attributes', 'responses') > 0   -- non-empty via length, not LIKE
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
        parseDateTime64BestEffortOrNull(JSONExtractString(resp, 1)) as response_ts,
        JSONExtractString(resp, 2) as response_row_id,
        -- contact_id arrives as raw JSON (number, or string with quotes);
        -- normalize to a clean numeric string so it matches contacts.id /
        -- dim_learner everywhere and never collapses to null.
        nullIf(replaceRegexpAll(JSONExtractRaw(resp, 3), '[^0-9]', ''), '') as contact_id,
        JSONExtractString(resp, 4) as session_id,
        JSONExtractString(resp, 5) as question_key,
        JSONExtractString(resp, 6) as answer_value
    from exploded
)

-- Drop excluded contacts (test cadre / seed) at the earliest point that carries
-- contact_id, so every flow-based metric + enrolment excludes them. Gated OFF by
-- default during the test phase; flip apply_contact_exclusions at go-live.
select *
from responses_flat
{% if var('apply_contact_exclusions', false) %}
where contact_id not in (
    select contact_id from {{ ref('int_contact_profile') }} where is_excluded
)
{% endif %}
