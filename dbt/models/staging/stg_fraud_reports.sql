SELECT
    fraud_report_id,
    attempt_id,
    reported_date,
    amount_eur AS fraud_amount_eur

FROM {{ source('raw', 'fraud_reports') }}