{{ config(materialized='table', engine='MergeTree()',
          order_by='(package_id, response_ts)', settings={'allow_nullable_key': 1}) }}

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
)

select
    package_id,
    -- Turn Flow-Results response tuple (positional per the data-package spec):
    --   [1]=timestamp  [2]=row_id  [3]=contact_id  [4]=session_id
    --   [5]=question_key  [6]=answer  [7]=metadata
    parseDateTime64BestEffortOrNull(JSONExtractString(resp, 1)) as response_ts,
    JSONExtractString(resp, 2) as response_row_id,
    JSONExtractRaw(resp, 3)    as contact_id,
    JSONExtractString(resp, 4) as session_id,
    JSONExtractString(resp, 5) as question_key,
    JSONExtractString(resp, 6) as answer_value
from exploded