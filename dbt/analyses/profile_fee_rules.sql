/*
Q1: row count
Result: 21
SELECT
    COUNT(*) AS row_count
FROM {{ source('raw', 'fee_rules') }}
*/

/*
Q2: key check (no ID column; a rule = bank + card type + region + start date)
Result: 21 rows / 21 distinct → the four columns together are unique.
   Grain: one fee rule per bank × card type × region × period.
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT CONCAT(bank_id, card_type, region, CAST(valid_from AS STRING))) AS distinct_keys
FROM {{ source('raw', 'fee_rules') }}
*/

/*
Q3: empty values per column
Result: 0 everywhere except valid_to = 18 → allowed: empty = rule still valid
SELECT
    COUNTIF(bank_id IS NULL OR bank_id = '') AS bank_id_nulls,
    COUNTIF(card_type IS NULL OR card_type = '') AS card_type_nulls,
    COUNTIF(region IS NULL OR region = '') AS region_nulls,
    COUNTIF(fee_pct IS NULL) AS fee_pct_nulls,
    COUNTIF(fixed_fee_eur IS NULL) AS fixed_fee_eur_nulls,
    COUNTIF(valid_from IS NULL) AS valid_from_nulls,
    COUNTIF(valid_to IS NULL) AS valid_to_nulls
FROM {{ source('raw', 'fee_rules') }}
*/

/*
Q4: values in category columns
Result: bank_id BNK_DE 6, BNK_FR 9, BNK_NL 6; card_type credit 12, debit 9;
   region domestic 7, non_eu 7, other_eu 7 → all allowed values
SELECT 'bank_id' AS column_name, bank_id AS value, COUNT(*) AS rows_ FROM {{ source('raw', 'fee_rules') }} GROUP BY bank_id
UNION ALL
SELECT 'card_type', card_type, COUNT(*) FROM {{ source('raw', 'fee_rules') }} GROUP BY card_type
UNION ALL
SELECT 'region', region, COUNT(*) FROM {{ source('raw', 'fee_rules') }} GROUP BY region
ORDER BY column_name, value
*/

/*
Q5: min/max of numbers and dates
Result: fee_pct 0.6–3.0 (percent); fixed_fee_eur 0.10–0.15; valid_from 2019-06-01 to 2025-07-01;
   valid_to 2025-06-30 → plausible; Bank FR changed its credit fees on 1 Jul 2025 (rulebook §5)
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
