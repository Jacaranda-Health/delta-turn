{{ config(order_by='contact_id') }}

-- ============================================================
-- contact_profile  (intermediate — RESTRICTED: CONTAINS PII)
-- Purpose : One row per contact, profile attributes from Turn's native-JSON
--           `details` column via dot notation. The ONLY model holding phone +
--           names. Do NOT expose to Power BI — BI reads learners. Restrict
--           grants on this model's schema.
-- Grain   : One row per contact (Turn contacts.id).
-- Source  : contacts.
-- ============================================================

with c as (
    select
        toString(toUInt64OrNull(replaceRegexpOne(toString(id), '\\.0*$', ''))) as contact_id,
        uuid    as turn_uuid,
        details as d          -- native JSON
    from {{ ref('contacts') }}
),
prof as (
    select
        contact_id,
        turn_uuid,
        CAST(d.whatsapp_id AS String)           as phone,          -- PII
        CAST(d.whatsapp_profile_name AS String) as profile_name,   -- PII
        CAST(d.name AS String)                  as given_name,     -- PII
        -- cadre: prefer provider_cadre, then cadre / cadre_1; trim, upper, de-underscore
        replaceRegexpAll(
            coalesce(
                nullIf(upper(trimBoth(CAST(d.provider_cadre AS String))), ''),
                nullIf(upper(trimBoth(CAST(d.cadre AS String))),          ''),
                nullIf(upper(trimBoth(CAST(d.cadre_1 AS String))),        '')
            ),
            '[_-]+', ' '
        )                                       as cadre_norm,
        -- county: prefer county_name (ignore placeholder), then county
        coalesce(
            nullIf(nullIf(upper(trimBoth(CAST(d.county_name AS String))), ''), 'COUNTY NOT LISTED'),
            nullIf(upper(trimBoth(CAST(d.county AS String))), '')
        )                                       as county,
        trimBoth(CAST(d.facility AS String))    as facility_raw,
        CAST(d.learning_path AS String)         as learning_path,
        CAST(d.completion_status AS String)     as turn_completion_status,
        parseDateTime64BestEffortOrNull(CAST(d.enrollment_date AS String)) as enrollment_at,
        (CAST(d.opted_in AS String)   = 'true') as opted_in,
        (CAST(d.is_blocked AS String) = 'true') as is_blocked,
        -- tester signal across all cadre fields (matches SYSTEM_TESTER / System Tester)
        (replaceRegexpAll(upper(trimBoth(CAST(d.cadre AS String))),          '[_-]+', ' ') = 'SYSTEM TESTER'
         or replaceRegexpAll(upper(trimBoth(CAST(d.provider_cadre AS String))), '[_-]+', ' ') = 'SYSTEM TESTER'
         or replaceRegexpAll(upper(trimBoth(CAST(d.cadre_1 AS String))),        '[_-]+', ' ') = 'SYSTEM TESTER') as is_tester
    from c
    where contact_id is not null
)
select
    p.contact_id as contact_id,
    p.turn_uuid,
    p.phone,
    p.profile_name,
    p.given_name,
    -- canonical cadre from the cadre_map seed; non-blank unmapped -> Other; blank stays blank
    multiIf(
        p.cadre_norm is null, cast(null as Nullable(String)),
        cm.cadre != '', cm.cadre,
        'Other Cadre not listed'
    )                                            as cadre,
    p.county,
    p.facility_raw,
    p.learning_path,
    p.turn_completion_status,
    p.enrollment_at,
    p.opted_in,
    p.is_blocked,
    -- exclusion FLAG (enforcement gated by apply_contact_exclusions downstream):
    -- known test cadre OR manual seed.
    (p.is_tester
     or p.contact_id in (select toString(contact_id) from {{ ref('excluded_contacts') }})
    ) as is_excluded
from prof p
left join {{ ref('cadre_map') }} cm on p.cadre_norm = cm.cadre_raw
