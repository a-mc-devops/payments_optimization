/*
Q1: row count
Result: 162
SELECT
    COUNT(*) AS row_count
FROM {{ source('raw', 'fraud_reports') }}
*/

/*
Q2: key check
Result: 162 / 162 / 162 → fraud_report_id unique, never empty. Grain: one row per reported payment.
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT fraud_report_id) AS distinct_ids,
    COUNT(fraud_report_id) AS non_null_ids
FROM {{ source('raw', 'fraud_reports') }}
*/

/*
Q3: empty values per column
Result: 0 everywhere
SELECT
    COUNTIF(fraud_report_id IS NULL OR fraud_report_id = '') AS fraud_report_id_nulls,
    COUNTIF(attempt_id IS NULL OR attempt_id = '') AS attempt_id_nulls,
    COUNTIF(reported_date IS NULL) AS reported_date_nulls,
    COUNTIF(amount_eur IS NULL) AS amount_eur_nulls
FROM {{ source('raw', 'fraud_reports') }}
*/

/*
Q4: min/max of amounts and dates
Result: reported_date 2025-01-21 to 2026-01-27; amount_eur 4.99–1,335.57
   → plausible; no report after the 31 Jan 2026 data cut-off
SELECT
    MIN(reported_date) AS reported_min,
    MAX(reported_date) AS reported_max,
    MIN(amount_eur) AS amount_min,
    MAX(amount_eur) AS amount_max
FROM {{ source('raw', 'fraud_reports') }}
*/
