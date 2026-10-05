/*
Q1: row count
Result: 3
SELECT
    COUNT(*) AS row_count
FROM {{ source('raw', 'banks') }}
*/

/*
Q2: key check
Result: 3 / 3 / 3 → bank_id unique, never empty. Grain: one row per bank.
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT bank_id) AS distinct_ids,
    COUNT(bank_id) AS non_null_ids
FROM {{ source('raw', 'banks') }}
*/

/*
Q3: empty values per column
Result: 0 everywhere
SELECT
    COUNTIF(bank_id IS NULL OR bank_id = '') AS bank_id_nulls,
    COUNTIF(bank_name IS NULL OR bank_name = '') AS bank_name_nulls,
    COUNTIF(country IS NULL OR country = '') AS country_nulls
FROM {{ source('raw', 'banks') }}
*/

/*
Q4: all rows (only 3)
Result: BNK_DE / Bank DE / DE, BNK_FR / Bank FR / FR, BNK_NL / Bank NL / NL → as expected
SELECT *
FROM {{ source('raw', 'banks') }}
ORDER BY bank_id
*/
