SELECT
    f.fraud_report_id,
    p.attempt_id,
    p.outcome
FROM {{ ref('stg_fraud_reports') }} AS f
JOIN {{ ref('stg_payment_attempts') }} AS p
    ON f.attempt_id = p.attempt_id
WHERE p.outcome != 'approved'

