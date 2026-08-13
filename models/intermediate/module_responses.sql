{{ config(order_by='(module_name, response_ts)') }}

with resp as (
    select
        r.*,
        CAST(pk.attributes.title AS String) as title
    from {{ ref('flow_responses') }} r
    left join {{ ref('flow_results_packages') }} pk
        on r.package_id = pk.id
),

classified as (
    select
        *,
        multiIf(
            title ILIKE '%rmc%',                                'RMC',
            match(lower(title), '\\baph'),                      'APH',
            (title ILIKE '%comms_%' OR title ILIKE '%comm_intro%'), 'Communication',
            (title ILIKE '%pph%' OR title ILIKE '%amstl%' OR title ILIKE '%4ts%'
             OR title ILIKE '%blood loss%' OR title ILIKE '%essential skills%'
             OR title ILIKE '%emotive%' OR title ILIKE '%referral%'
             OR title ILIKE '%pphtypes%'),                      'PPH',
            NULL
        ) as module_name
    from resp
)

select
    {{ dbt_utils.generate_surrogate_key(['package_id', 'response_row_id']) }} as id,
    multiIf(
        -- PPH -----------------------------------------------------------
        module_name = 'PPH' and (title ILIKE '%post_test%' or title ILIKE '%post-test%' or title ILIKE '%post test%'), 'pph_post_test',
        module_name = 'PPH' and title ILIKE '%referral%',                                     'pph_referral_and_transfer',
        module_name = 'PPH' and (title ILIKE '%monitoring%' or title ILIKE '%documentation%'), 'pph_monitoring_and_documentation',
        module_name = 'PPH' and title ILIKE '%essential%skill%',                              'pph_essential_skills',
        module_name = 'PPH' and title ILIKE '%emotive%',                                      'pph_emotive_bundle',
        module_name = 'PPH' and (title ILIKE '%blood loss%' or title ILIKE '%measuring%'),    'pph_measuring_blood_loss',
        module_name = 'PPH' and title ILIKE '%amstl%',                                        'pph_amstl',
        module_name = 'PPH' and title ILIKE '%4ts%',                                          'pph_4Ts',
        module_name = 'PPH' and (title ILIKE '%pphtypes%' or title ILIKE '%definition%'),     'pph_definition_types_of_pph',
        module_name = 'PPH' and (title ILIKE '%intro%' or title ILIKE '%welcome%' or title ILIKE '%pretest%'),         'pph_welcome_pretest',
        -- RMC -----------------------------------------------------------
        module_name = 'RMC' and (title ILIKE '%post_test%' or title ILIKE '%post-test%' or title ILIKE '%post test%' or title ILIKE '%quiz%'), 'rmc_post_test',
        module_name = 'RMC' and (title ILIKE '%person%centred%' or title ILIKE '%person%centered%' or title ILIKE '%maternity care%'),         'rmc_person_centred_maternity_care',
        module_name = 'RMC' and (title ILIKE '%d&a%' or title ILIKE '%postpartum%'),          'rmc_d&a_types_experience_by_postpartumwomen',
        module_name = 'RMC' and title ILIKE '%barrier%',                                      'rmc_barriers_to_quality_maternal_healthcare',
        module_name = 'RMC' and (title ILIKE '%human right%' or title ILIKE '%human_right%'), 'rmc_human_rights',
        module_name = 'RMC' and title ILIKE '%definition%',                                   'rmc_definition',
        module_name = 'RMC' and (title ILIKE '%intro%' or title ILIKE '%welcome%' or title ILIKE '%pretest%'),         'rmc_welcome_pretest',
        -- COMMS ---------------------------------------------------------
-- COMMS ---------------------------------------------------------
        module_name = 'Communication' and (title ILIKE '%post_test%' or title ILIKE '%post-test%' or title ILIKE '%post test%' or title ILIKE '%quiz%'), 'comms_post_test',
        module_name = 'Communication' and title ILIKE '%emergenc%',                                             'comms_communication_in_emergencies',
        module_name = 'Communication' and (title ILIKE '%trauma%' or title ILIKE '%escalation%'),               'comms_trauma-Informed_communication_and_de-escalation',
        module_name = 'Communication' and (title ILIKE '%cultural%' or title ILIKE '%awareness%'),              'comms_cultural_awareness',
        module_name = 'Communication' and (title ILIKE '%core%' or title ILIKE '%communication skill%'),        'comms_core_communication_skills',
        module_name = 'Communication' and (title ILIKE '%definition%' or title ILIKE '%comms_2%'),              'comms_definitions',
        module_name = 'Communication' and (title ILIKE '%intro%' or title ILIKE '%welcome%' or title ILIKE '%pretest%'), 'comms_welcome_pretest',             
        -- APH -----------------------------------------------------------
        module_name = 'APH' and (title ILIKE '%post_test%' or title ILIKE '%post-test%' or title ILIKE '%post test%' or title ILIKE '%quiz%'), 'aph_post_test',
        module_name = 'APH' and title ILIKE '%referral%',                                     'aph_referral_and_transfer',
        module_name = 'APH' and title ILIKE '%abruption%',                                    'aph_placental_abruption',
        module_name = 'APH' and title ILIKE '%praevia%',                                      'aph_placental_praevia',
        module_name = 'APH' and (title ILIKE '%emergency%' or title ILIKE '%resuscitation%'), 'aph_emergency_response_initial_resuscitation',
        module_name = 'APH' and (title ILIKE '%diagnosis%' or title ILIKE '%assessment%'),    'aph_diagnosis_assessment',
        module_name = 'APH' and title ILIKE '%definition%',                                   'aph_definitions',
        module_name = 'APH' and (title ILIKE '%intro%' or title ILIKE '%welcome%' or title ILIKE '%pretest%'), 'aph_welcome_pretest',
        NULL
    ) as mini_module,
    module_name,
    package_id,
    title as package_title,
    response_ts,
    response_row_id,
    contact_id,
    session_id,
    question_key,
    answer_value
from classified
where module_name is not null
  and title not ilike '%copy of%'
  and title not ilike '%kelvin%'
  and title not ilike '%clean%'
  and title not ilike '%rag_qa%'
  and title not ilike '%demo%'
  and title not ilike '%untitled%'
