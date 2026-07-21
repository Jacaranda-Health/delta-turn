{{ config(
    materialized='table',
    engine='MergeTree',
    order_by='(date_day)'
) }}

with dates as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2026-06-01' as date)",
        end_date="today() + interval '1 day'"
    ) }}
)

select
    date_day,
    toYear(date_day)                                                                    as year,
    toMonth(date_day)                                                                   as month_number,
    arrayElement(['January','February','March','April','May','June','July','August',
                  'September','October','November','December'], toMonth(date_day))      as month_name,
    concat(arrayElement(['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct',
                         'Nov','Dec'], toMonth(date_day)), ' ', toString(toYear(date_day))) as month_year,
    toStartOfMonth(date_day)                                                            as month_start,
    concat('Q', toString(toQuarter(date_day)))                                         as quarter,
    toISOWeek(date_day)                                                                 as week_number,
    toDayOfWeek(date_day)                                                               as weekday_number,
    arrayElement(['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'],
                 toDayOfWeek(date_day))                                                 as weekday_name,
    toDayOfWeek(date_day) > 5                                                           as is_weekend,
    formatDateTime(date_day, '%Y%m')                                                    as year_month_sort,
    concat(toString(toYear(date_day)), '-W',
           leftPad(toString(toISOWeek(date_day)), 2, '0'))                             as year_week,
    toYear(date_day) * 100 + toISOWeek(date_day)                                       as year_week_sort,
    (toYear(date_day) = toYear(today())
        and toQuarter(date_day) = toQuarter(today()))                                  as is_current_quarter,
    (toYear(date_day) = toYear(today())
        and toMonth(date_day) = toMonth(today()))                                      as is_current_month
from dates