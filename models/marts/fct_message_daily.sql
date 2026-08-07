-- ============================================================
-- fct_message_daily  (mart)
-- Purpose : Per-learner daily message counts. Contact-grain so profile slicers
--           (dim_learner: cadre / facility / county) can filter outbound/inbound
--           volume. Relate contact_id -> dim_learner and day -> dim_date.
-- Grain   : One row per (contact, day). contact_id may be null for messages whose
--           phone isn't in contacts (unattributed).
-- Source  : int_message_events.
-- ============================================================

{{ config(materialized='table', engine='MergeTree', order_by='day',
          settings={'allow_nullable_key': 1}) }}

select
    {{ dbt_utils.generate_surrogate_key(['contact_id', 'day']) }} as id,
    contact_id,
    day,
    countIf(direction = 'outbound') as outbound_msgs,
    countIf(direction = 'inbound')  as inbound_msgs
from {{ ref('int_message_events') }}
group by contact_id, day
