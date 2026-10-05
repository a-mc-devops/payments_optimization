/*
SELECT
    COUNTIF(bank_id IS NULL OR bank_id = '') AS bank_id_nulls,
    COUNTIF(bank_name IS NULL OR bank_name = '') AS bank_name_nulls,
    COUNTIF(country IS NULL OR country = '') AS country_nulls
FROM {{ source('raw', 'banks') }}
*/

/*
SELECT
    bank_id,
    bank_name,
    country
FROM {{ source('raw', 'banks') }}
WHERE bank_id IS NULL OR bank_name IS NULL OR country IS NULL
*/

/*
SELECT
    COUNT(*) as row_count,
    COUNT(DISTINCT bank_id) AS distinct_bank_id,
    COUNT(bank_id) as bank_id_count
FROM {{ source('raw', 'fee_rules') }}
*/

/*
SELECT 
    COUNT(*) AS row_count,
    COUNT(DISTINCT CONCAT(bank_id, card_type, region, valid_from) ) AS distinct_keys
FROM {{ source('raw', 'fee_rules') }}
*/

/*
SELECT
    COUNTIF(bank_id IS NULL) AS bank_id_nulls,
    COUNTIF(card_type IS NULL) AS card_type_nulls,
    COUNTIF(region IS NULL) AS region_nulls,
    COUNTIF(fee_pct IS NULL) AS fee_pct_nulls,
    COUNTIF(fixed_fee_eur IS NULL) AS fixed_fee_eur_nulls,
    COUNTIF(valid_from IS NULL) AS valid_from_nulls,
    COUNTIF(valid_to IS NULL) AS valid_to_nulls  
FROM {{ source('raw', 'fee_rules') }}
*/

/*
SELECT
    COUNT(DISTINCT bank_id) AS distinct_bank_id_count,
    COUNT(DISTINCT card_type)AS distinct_card_type_count,
    COUNT(DISTINCT region) AS distinct_region_count
FROM {{ source('raw', 'fee_rules') }}
*/

/*
SELECT
    bank_id,
    COUNT(*) AS rows_
FROM {{ source('raw', 'fee_rules') }}
GROUP BY bank_id
*/

/*
SELECT
    MIN(fee_pct) AS fee_pct_min,
    MAX(fee_pct) AS fee_pct_max,
    MIN(fixed_fee_eur) AS fixed_fee_eur_min,
    MAX(fixed_fee_eur) AS fixed_fee_eur_max,
    MIN(valid_from) AS valid_from_min,
    MAX(valid_from) AS valid_from_max,
    MIN(valid_to) AS valid_to_min,
    MAX(valid_to) AS valid_to_max
FROM {{ source('raw', 'fee_rules') }}
*/

/*
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT payout_id) as distinct_payout_id_count,
    COUNT(payout_id) AS payout_id_count

FROM {{ source('raw', 'bank_payouts') }}
*/

/*
SELECT
    *
FROM {{ source('raw', 'bank_payouts') }}
WHERE net_eur != gross_eur - fees_eur
*/

/*
SELECT
    *
FROM {{ source('raw', 'bank_payouts') }} AS p
LEFT JOIN {{ source('raw', 'shops') }} AS s
    ON p.shop_id = s.shop_id
WHERE s.shop_id IS NULL
*/

/*
SELECT
    *
FROM {{ source('raw', 'bank_payouts') }} AS p
LEFT JOIN {{ source('raw', 'banks') }} AS b
    ON p.bank_id = b.bank_id
WHERE b.bank_id IS NULL
*/

/*
SELECT
    FORMAT_DATE('%a', payment_date) AS payment_day,
    FORMAT_DATE('%a', payout_date) AS payout_date,
    DATE_DIFF(payout_date, payment_date, DAY) AS day_diff,
    COUNT(*) as row_count
FROM {{ source('raw', 'bank_payouts') }}
GROUP BY
    FORMAT_DATE('%a', payment_date),
    FORMAT_DATE('%a', payout_date),
    DATE_DIFF(payout_date, payment_date, DAY)
*/

/*
WITH days AS (
    SELECT
        FORMAT_DATE('%a', payment_date) AS payment_day,
        FORMAT_DATE('%a', payout_date) AS payout_day,
        DATE_DIFF(payout_date, payment_date, DAY) AS day_diff
    FROM {{ source('raw', 'bank_payouts') }}
)
SELECT
    payment_day,
    payout_day,
    day_diff,
    COUNT(*) AS row_count
FROM days
GROUP BY payment_day, payout_day, day_diff
ORDER BY day_diff
*/

/*
WITH days AS (
    SELECT
        FORMAT_DATE('%a', payment_date) AS payment_day,
        FORMAT_DATE('%a', payout_date) AS payout_day,
        DATE_DIFF(payout_date, payment_date, DAY) AS day_diff
    FROM {{ source('raw', 'bank_payouts') }}
)
SELECT
    payment_day,
    payout_day,
    day_diff,
    COUNT(*) AS row_count
FROM days
WHERE day_diff > 1 AND (payment_day NOT IN('Sat', 'Fri')) 
GROUP BY payment_day, payout_day, day_diff
ORDER BY day_diff
*/

/*
SELECT
    COUNT(*) AS row_count,
    COUNT(fraud_report_id) AS id_count,
    COUNT(DISTINCT fraud_report_id) AS distinct_bank_id_count
FROM {{ source('raw', 'fraud_reports')}}
*/

/*
SELECT
    fraud_report_id,
    f.attempt_id,
    reported_date,
    f.amount_eur,
    p.amount_eur

FROM {{ source('raw', 'fraud_reports') }} as f
LEFT JOIN {{ source('raw', 'payment_attempts') }} as p
    ON f.attempt_id = p.attempt_id
WHERE p.attempt_id IS NULL OR p.outcome != 'approved'
*/

/*
WITH dates AS(
SELECT
    f.reported_date,
    p.attempted_at,
    DATE_DIFF(f.reported_date, DATE(p.attempted_at), DAY) AS days_to_report
FROM {{ source('raw', 'fraud_reports') }} as f
LEFT JOIN {{ source('raw', 'payment_attempts') }} as p
    ON f.attempt_id = p.attempt_id
)

SELECT  
    MIN(days_to_report) AS min_days_to_report,
    MAX(days_to_report) AS max_days_to_report,
    AVG(days_to_report) AS average_days_to_report,
    APPROX_QUANTILES(days_to_report, 100)[OFFSET(50)] AS approx_median_to_report
FROM dates
*/

/*
WITH counts AS(
    SELECT
        COUNT(*) AS row_count,
        COUNT(attempt_id) AS attempt_id_count,
        COUNT(DISTINCT attempt_id) AS distinct_attempt_id_count,
        COUNT(payment_id) AS payment_id_count,
        COUNT(DISTINCT payment_id) AS distinct_payment_id_count
    FROM {{ source('raw', 'payment_attempts') }}
)

SELECT
    row_count,
    attempt_id_count,
    distinct_attempt_id_count,
    attempt_id_count - distinct_attempt_id_count AS duplicate_attempt_id_count,
    payment_id_count,
    distinct_payment_id_count,
    payment_id_count - distinct_payment_id_count AS duplicate_payment_id_count
FROM counts
*/

/*
SELECT
    attempt_id,
    COUNT(attempt_id) as attempt_id_count
FROM {{ source('raw', 'payment_attempts') }}
GROUP BY attempt_id
HAVING COUNT(attempt_id) > 1
*/

/*
WITH cleaning AS (
    SELECT
        DISTINCT attempt_id,
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
    FROM {{ source('raw', 'payment_attempts') }}
)

SELECT
    COUNT(*) AS row_count,
    COUNT(attempt_id) AS attempt_id_count,
    COUNT(DISTINCT attempt_id) AS distinct_attempt_id_count,
    COUNT(payment_id) AS payment_id_count,
    COUNT(DISTINCT payment_id) AS distinct_payment_id_count
FROM cleaning
*/

/*
SELECT
    decline_type,
    COUNT(decline_type) AS count
FROM {{ source('raw', 'payment_attempts') }}
GROUP BY decline_type
*/

/*
SELECT
    outcome,
    COUNT(*) AS row_count
FROM {{ source('raw', 'payment_attempts') }}
GROUP BY outcome
*/

/*
SELECT
    outcome,
    decline_type,
    COUNT(*) AS row_count
FROM {{ source('raw', 'payment_attempts') }}
GROUP BY outcome, decline_type
HAVING (outcome = 'declined' AND decline_type IS NULL) OR (outcome != 'declined' AND decline_type IS NOT NULL)
*/