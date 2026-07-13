{{ config(materialized='view') }}
select * from {{ source('turn', 'flow_results_packages') }}