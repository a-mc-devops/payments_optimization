SELECT
    payment_id,
    MAX(CASE WHEN is_approved THEN attempt_id END) AS approved_attempt_id,
    COUNT(attempt_number) AS number_of_tries,
    MAX_BY(outcome, attempt_number) AS final_outcome,
    (MAX_BY(outcome, attempt_number) = 'approved' AND COUNT(attempt_number) > 1) AS is_saved_by_retry,
    MAX(attempt_date) AS payment_date,
    shop_id,
    bank_id,
    amount_eur,
    card_country,
    card_type,
    business_type,
    three_ds_used,
    retries_on_date,
    three_ds_policy,
    three_ds_threshold_eur
    
FROM {{ ref('int_attempts') }}
GROUP BY payment_id, shop_id, bank_id, amount_eur, card_country, card_type, business_type, three_ds_used, retries_on_date, three_ds_policy, three_ds_threshold_eur
