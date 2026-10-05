WITH dedup AS(
    SELECT
        DISTINCT *
    FROM {{ source('raw', 'payment_attempts')}}
)

SELECT
    attempt_id,
    payment_id,
    attempt_number,
    initiated_by,
    shop_id,
    attempted_at,
    amount_eur,
    card_country,
    card_type,
    bank_id,
    three_ds_used,
    outcome,
    decline_type
FROM dedup