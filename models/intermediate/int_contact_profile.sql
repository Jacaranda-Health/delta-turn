{{ config(order_by='contact_id') }}

-- ============================================================
-- int_contact_profile  (intermediate — RESTRICTED: CONTAINS PII)
-- Purpose : One row per contact, profile attributes unnested from Turn's
--           `details` JSON. This is the ONLY model that holds phone + names.
--           Do NOT expose to Power BI — BI reads dim_learner (surrogate key,
--           no direct identifiers). Restrict grants on this model's schema.
-- Grain   : One row per contact (Turn contacts.id).
-- Source  : stg_turn__contacts.
-- Note    : Booleans are read via string compare ('true') — JSONExtractBool is
--           unreliable on this data and mis-flagged every row.
-- ============================================================

with c as (
    select
        toString(toUInt64OrNull(replaceRegexpOne(toString(id), '\\.0*$', ''))) as contact_id,
        uuid              as turn_uuid,
        toString(details) as d
    from {{ ref('stg_turn__contacts') }}
),
prof as (
    select
        contact_id,
        turn_uuid,
        JSONExtractString(d, 'whatsapp_id')           as phone,          -- PII
        JSONExtractString(d, 'whatsapp_profile_name') as profile_name,   -- PII
        JSONExtractString(d, 'name')                  as given_name,     -- PII
        -- cadre: prefer the newer provider_cadre, then cadre / cadre_1; trim, upper,
        -- underscores/hyphens -> spaces (CLINICAL_OFFICER -> CLINICAL OFFICER)
        replaceRegexpAll(
            coalesce(
                nullIf(upper(trimBoth(JSONExtractString(d, 'provider_cadre'))), ''),
                nullIf(upper(trimBoth(JSONExtractString(d, 'cadre'))),          ''),
                nullIf(upper(trimBoth(JSONExtractString(d, 'cadre_1'))),        '')
            ),
            '[_-]+', ' '
        )                                             as cadre_norm,
        coalesce(
            nullIf(nullIf(upper(trimBoth(JSONExtractString(d, 'county_name'))), ''), 'COUNTY NOT LISTED'),
            nullIf(upper(trimBoth(JSONExtractString(d, 'county'))), '')
        )                                             as county,
        trimBoth(JSONExtractString(d, 'facility'))              as facility_raw,
        JSONExtractString(d, 'learning_path')         as learning_path,
        JSONExtractString(d, 'completion_status')     as turn_completion_status,
        parseDateTime64BestEffortOrNull(JSONExtractString(d, 'enrollment_date')) as enrollment_at,
        (JSONExtractString(d, 'opted_in')   = 'true') as opted_in,
        (JSONExtractString(d, 'is_blocked') = 'true') as is_blocked,
        (replaceRegexpAll(upper(trimBoth(JSONExtractString(d, 'cadre'))),          '[_-]+', ' ') = 'SYSTEM TESTER'
         or replaceRegexpAll(upper(trimBoth(JSONExtractString(d, 'provider_cadre'))), '[_-]+', ' ') = 'SYSTEM TESTER'
         or replaceRegexpAll(upper(trimBoth(JSONExtractString(d, 'cadre_1'))),        '[_-]+', ' ') = 'SYSTEM TESTER') as is_tester
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
    -- exclusion FLAG (computed always; enforcement is gated by the
    -- apply_contact_exclusions var downstream). Reliable signal only:
    -- known test cadre OR manual seed. is_blocked/opted_in kept as columns
    -- above for later review before adding them to the rule.
    (p.is_tester
     or p.contact_id in (select toString(contact_id) from {{ ref('excluded_contacts') }})
    ) as is_excluded
from prof p
left join {{ ref('cadre_map') }} cm        on p.cadre_norm = cm.cadre_raw
