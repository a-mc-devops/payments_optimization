SELECT
    bank_id,
    card_type,
    region AS card_region,
    fee_pct AS bank_fee_pct,
    fixed_fee_eur AS bank_fixed_fee_eur,
    valid_from,
    valid_to

FROM {{ source('raw', 'fee_rules') }}