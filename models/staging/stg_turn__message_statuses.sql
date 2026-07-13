{{ config(materialized='view') }}
select * from {{ source('turn', 'message_statuses') }}