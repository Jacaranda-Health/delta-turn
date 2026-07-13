{{ config(materialized='view') }}
select * from {{ source('turn', 'contacts') }}