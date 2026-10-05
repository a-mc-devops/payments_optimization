/*
Q1: row count
Result: 106,130
SELECT
    COUNT(*) AS row_count
FROM {{ source('raw', 'payment_attempts') }}
*/

/*
Q2: key check
Result: 106,130 rows / 105,813 distinct attempt_id / 106,130 non-empty
   → attempt_id NOT unique: 317 extra rows. Grain: one row per try to pay.
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT attempt_id) AS distinct_ids,
    COUNT(attempt_id) AS non_null_ids
FROM {{ source('raw', 'payment_attempts') }}
*/

/*
Q3: are the duplicates exact copies?
Result: 105,813 distinct full rows = 105,813 distinct attempt_ids
   → yes, every duplicate is an exact copy. Fix in staging: SELECT DISTINCT *
SELECT
    COUNT(DISTINCT TO_JSON_STRING(t)) AS distinct_full_rows
FROM {{ source('raw', 'payment_attempts') }} AS t
*/

/*
Q4: empty values per column
Result: 0 everywhere except decline_type = 91,813 → allowed: only filled when a try is declined
SELECT
    COUNTIF(attempt_id IS NULL OR attempt_id = '') AS attempt_id_nulls,
    COUNTIF(payment_id IS NULL OR payment_id = '') AS payment_id_nulls,
    COUNTIF(attempt_number IS NULL) AS attempt_number_nulls,
    COUNTIF(initiated_by IS NULL OR initiated_by = '') AS initiated_by_nulls,
    COUNTIF(shop_id IS NULL OR shop_id = '') AS shop_id_nulls,
    COUNTIF(attempted_at IS NULL) AS attempted_at_nulls,
    COUNTIF(amount_eur IS NULL) AS amount_eur_nulls,
    COUNTIF(card_country IS NULL OR card_country = '') AS card_country_nulls,
    COUNTIF(card_type IS NULL OR card_type = '') AS card_type_nulls,
    COUNTIF(bank_id IS NULL OR bank_id = '') AS bank_id_nulls,
    COUNTIF(three_ds_used IS NULL) AS three_ds_used_nulls,
    COUNTIF(outcome IS NULL OR outcome = '') AS outcome_nulls,
    COUNTIF(decline_type IS NULL OR decline_type = '') AS decline_type_nulls
FROM {{ source('raw', 'payment_attempts') }}
*/

/*
Q5: values in category columns (raw rows, duplicates included)
Result: card_country DE 28,751 / ES 7,552 / FR 22,243 / NL 29,192 / UK 10,641 / US 7,751
   card_type credit 45,631 / debit 60,499; initiated_by customer 101,468 / platform 4,662
   outcome approved 88,832 / declined 14,317 / gave_up 2,981
   decline_type empty 91,813 / permanent 3,629 / try_again 10,688 → all allowed values
SELECT 'card_country' AS column_name, card_country AS value, COUNT(*) AS rows_ FROM {{ source('raw', 'payment_attempts') }} GROUP BY 2
UNION ALL SELECT 'card_type', card_type, COUNT(*) FROM {{ source('raw', 'payment_attempts') }} GROUP BY 2
UNION ALL SELECT 'initiated_by', initiated_by, COUNT(*) FROM {{ source('raw', 'payment_attempts') }} GROUP BY 2
UNION ALL SELECT 'outcome', outcome, COUNT(*) FROM {{ source('raw', 'payment_attempts') }} GROUP BY 2
UNION ALL SELECT 'decline_type', decline_type, COUNT(*) FROM {{ source('raw', 'payment_attempts') }} GROUP BY 2
ORDER BY column_name, value
*/

/*
Q6: min/max of amounts and times
Result: amount_eur 4.99–4,000; attempted_at 2025-01-01 00:25:54 to 2025-12-31 23:30:24 (UTC)
   → plausible, all within 2025
SELECT
    MIN(amount_eur) AS amount_min,
    MAX(amount_eur) AS amount_max,
    MIN(attempted_at) AS first_attempt,
    MAX(attempted_at) AS last_attempt
FROM {{ source('raw', 'payment_attempts') }}
*/
