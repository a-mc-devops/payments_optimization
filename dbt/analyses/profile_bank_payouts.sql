/*
Q1: row count
Result: 11,281
SELECT
    COUNT(*) AS row_count
FROM {{ source('raw', 'bank_payouts') }}
*/

/*
Q2: key check
Result: 11,281 / 11,281 / 11,281 → payout_id unique, never empty.
   Grain: one payout per shop × bank × payment day.
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT payout_id) AS distinct_ids,
    COUNT(payout_id) AS non_null_ids
FROM {{ source('raw', 'bank_payouts') }}
*/

/*
Q3: empty values per column
Result: 0 everywhere
SELECT
    COUNTIF(payout_id IS NULL OR payout_id = '') AS payout_id_nulls,
    COUNTIF(shop_id IS NULL OR shop_id = '') AS shop_id_nulls,
    COUNTIF(bank_id IS NULL OR bank_id = '') AS bank_id_nulls,
    COUNTIF(payment_date IS NULL) AS payment_date_nulls,
    COUNTIF(payout_date IS NULL) AS payout_date_nulls,
    COUNTIF(payment_count IS NULL) AS payment_count_nulls,
    COUNTIF(gross_eur IS NULL) AS gross_eur_nulls,
    COUNTIF(fees_eur IS NULL) AS fees_eur_nulls,
    COUNTIF(net_eur IS NULL) AS net_eur_nulls
FROM {{ source('raw', 'bank_payouts') }}
*/

/*
Q4: values in category columns
Result: BNK_DE 6,405 / BNK_FR 2,375 / BNK_NL 2,501 → all 3 banks
SELECT
    bank_id,
    COUNT(*) AS rows_
FROM {{ source('raw', 'bank_payouts') }}
GROUP BY bank_id
ORDER BY bank_id
*/

/*
Q5: min/max of numbers and dates
Result: payment_date 2025-01-01 to 2025-12-31; payout_date 2025-01-02 to 2026-01-01;
   payment_count 1–97; gross_eur 4.99–18,304.39; fees_eur 0.13–305.39; net_eur 4.69–18,031.28
   → plausible; late-December payments are paid out in early 2026
SELECT
    MIN(payment_date) AS payment_date_min,
    MAX(payment_date) AS payment_date_max,
    MIN(payout_date) AS payout_date_min,
    MAX(payout_date) AS payout_date_max,
    MIN(payment_count) AS payment_count_min,
    MAX(payment_count) AS payment_count_max,
    MIN(gross_eur) AS gross_min,
    MAX(gross_eur) AS gross_max,
    MIN(fees_eur) AS fees_min,
    MAX(fees_eur) AS fees_max,
    MIN(net_eur) AS net_min,
    MAX(net_eur) AS net_max
FROM {{ source('raw', 'bank_payouts') }}
*/
