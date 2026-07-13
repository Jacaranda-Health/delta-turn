{{ config(materialized='table', engine='MergeTree()',
          order_by='(module_name, response_ts)',
          settings={'allow_nullable_key': 1}) }}

with resp as (
    select
        r.*,
        JSONExtractString(toString(pk.attributes), 'title') as title
    from {{ ref('int_flow_responses') }} r
    left join {{ ref('stg_turn__flow_results_packages') }} pk
        on r.package_id = pk.id
),

classified as (
    select
        *,
        multiIf(
            title ILIKE '%rmc%',                                'RMC',
            title ILIKE '%clim%',                               'Climate & Health',
            (title ILIKE '%comms_%' OR title ILIKE '%comm_intro%'), 'Communication',
            (title ILIKE '%pph%' OR title ILIKE '%amstl%' OR title ILIKE '%4ts%'
             OR title ILIKE '%blood loss%' OR title ILIKE '%essential skills%'
             OR title ILIKE '%emotive%' OR title ILIKE '%referral%'
             OR title ILIKE '%pphtypes%'),                      'PPH',
            NULL
        ) as module_name
    from resp
)

select
    module_name,
    package_id,
    title as package_title,
    response_ts,
    response_row_id,
    contact_id,
    session_id,
    question_key,
    answer_value
from classified
where module_name is not null