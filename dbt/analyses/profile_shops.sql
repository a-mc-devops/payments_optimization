/*
Q1: row count
Result: 24
SELECT 
    COUNT(*) AS row_count
FROM {{ source('raw', 'shops') }}
*/

/*
Q2: key check
Result: 24 / 24 / 24 → shop_id unique, never empty
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT shop_id) AS distinct_ids,
    COUNT(CASE WHEN shop_id IS NOT NULL THEN 1 END) AS non_null_ids
FROM {{ source('raw', 'shops') }}
*/

/*
Q3: empty values per column (NULL, and '' for text columns)
   Result: 0 everywhere except retries_on_date = 6, three_ds_threshold_eur = 16
   → Both allowed: 6 shops never switched retries on; threshold only for above_threshold shops.
   Open: are the 16 exactly the always/never shops?
SELECT
    COUNTIF(shop_id IS NULL OR shop_id = '') AS shop_id_nulls,
    COUNTIF(shop_name IS NULL OR shop_name = '') AS shop_name_nulls,
    COUNTIF(country IS NULL OR country = '') AS country_nulls,
    COUNTIF(business_type IS NULL OR business_type = '') AS business_type_nulls,
    COUNTIF(fee_pct IS NULL) AS fee_pct_nulls,
    COUNTIF(fixed_fee_eur IS NULL) AS fixed_fee_eur_nulls,
    COUNTIF(retries_on_date IS NULL) AS retries_on_date_nulls,
    COUNTIF(three_ds_policy IS NULL OR three_ds_policy = '') AS three_ds_policy_nulls,
    COUNTIF(three_ds_threshold_eur IS NULL) AS three_ds_threshold_eur_nulls
FROM {{ source('raw', 'shops') }}
*/

/* 
Q4: values in category columns
   Result: country NL/DE/FR 8 each; business_type 4 types, 6 each;
   three_ds_policy above_threshold/always/never 8 each
   → all match shops.json, no spelling variants

SELECT
    country, COUNT(*) AS shops
FROM {{ source('raw', 'shops') }}
GROUP BY country

SELECT
    business_type, COUNT(*) AS shops
FROM {{ source('raw', 'shops') }}
GROUP BY business_type

SELECT
    three_ds_policy, COUNT(*) AS shops
FROM {{ source('raw', 'shops') }}
GROUP BY three_ds_policy
*/

/* 
Q5: min/max of numbers and dates
   Result: fee_pct 0.9–2.4; fixed_fee_eur 0.0–0.25; retries_on_date 2025-03-17 to 2025-09-15;
   three_ds_threshold_eur 15–250 → all plausible
   fixed_fee_eur = 0 for S12, S16: both 1.5% + €0 = 2023 launch price (rulebook §6), allowed

SELECT
    MIN(fee_pct) AS fee_pct_min,
    MAX(fee_pct) AS fee_pct_max,
    MIN(fixed_fee_eur) AS fixed_fee_eur_min,
    MAX(fixed_fee_eur) AS fixed_fee_eur_max,
    MIN(retries_on_date) AS retries_on_date_min,
    MAX(retries_on_date) AS retries_on_date_max,
    MIN(three_ds_threshold_eur) AS three_ds_threshold_eur_min,
    MAX(three_ds_threshold_eur) AS three_ds_threshold_eur_max
FROM {{ source('raw', 'shops') }}

SELECT *
FROM {{ source('raw', 'shops') }}
WHERE fixed_fee_eur = 0
*/

/* 
Q6: rule — threshold filled if and only if policy = above_threshold
   Result: above_threshold 8 shops / 0 empty / 8 filled; always 8 / 8 / 0; never 8 / 8 / 0
   → rule holds for all 24 shops

SELECT
    three_ds_policy,
    COUNT(*) AS shops,
    COUNTIF(three_ds_threshold_eur IS NULL) AS threshold_empty,
    COUNTIF(three_ds_threshold_eur IS NOT NULL) AS threshold_filled
FROM {{ source('raw', 'shops') }}
GROUP BY three_ds_policy
*/
