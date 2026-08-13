{{ config(
    materialized='table',
    engine='MergeTree',
    order_by='(date_month)'
) }}

with dates as (
    {{ dbt_utils.date_spine(
        datepart="month",
        start_date="cast('2026-06-01' as date)",
        end_date="date_trunc('month', today()) + interval '1 month'"
    ) }}
)

select
    date_month,
    concat(arrayElement(['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct',
                         'Nov','Dec'], toMonth(date_month)), ' ', toString(toYear(date_month))) as month_year,
    formatDateTime(date_month, '%Y%m')                                                           as year_month_sort
from dates
