{{ config(materialized='view') }}
select * from {{ source('turn', 'messages') }}