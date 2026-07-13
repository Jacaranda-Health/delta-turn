{{ config(materialized='table', engine='MergeTree()',
          order_by='(package_id, response_ts)',
          settings={'allow_nullable_key': 1}) }}

with raw as (
    select assumeNotNull(toString(data)) as data_str
    from {{ source('turn', 'flow_results_responses') }}
    where toString(data) not like '%"responses":[]%'
),

pages as (
    select
        JSONExtractString(data_str, 'id') as package_id,
        JSONExtractArrayRaw(data_str, 'attributes', 'responses') as responses
    from raw
),

exploded as (
    select
        package_id,
        arrayJoin(responses) as resp
    from pages
)

select
    package_id,
    parseDateTime64BestEffortOrNull(JSONExtractString(resp, 1)) as response_ts,
    JSONExtractString(resp, 2)  as response_row_id,
    JSONExtractRaw(resp, 3)     as contact_id,
    JSONExtractString(resp, 4)  as session_id,
    JSONExtractString(resp, 5)  as question_key,
    JSONExtractString(resp, 6)  as answer_value
from exploded