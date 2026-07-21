-- Catches upstream type drift: if Airbyte re-types `timestamp`, the epoch parse
-- yields NULL silently. Any message that HAS a source timestamp but no parsed
-- event_ts is a parse failure, not missing data.
select
    m.id                  as message_id,
    toString(m.timestamp) as raw_timestamp
from {{ ref('stg_turn__messages') }} m
inner join {{ ref('int_message_events') }} e
    on m.id = e.message_id
where m.timestamp is not null
  and toString(m.timestamp) != ''
  and e.event_ts is null