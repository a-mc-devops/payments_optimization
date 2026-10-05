# Profiling notes: raw tables

Basic profiling of the six raw tables before building staging models: row count, key, empty values,
category values, min/max. Queries and results: `dbt/analyses/profile_<table>.sql`.

**Only fix needed:** remove 317 exact duplicate rows in `payment_attempts`. Everything else is clean.

**Column renames in staging:** see "Column names in staging" in `docs/data_model.md`.

**Rule tests** (marked *rule* below) compare columns or tables, which the four built-in dbt tests
can't do. All of them held on the raw data when checked on 2 Oct 2026. Built in Stage 2 with the
`dbt_utils` package (`unique_combination_of_columns`, `expression_is_true`) and one custom SQL test,
`dbt/tests/assert_fraud_reports_on_approved_attempts.sql`.

**Status (5 Oct 2026):** every test listed below is built in `dbt/models/staging/stg_<table>.yml`;
`dbt build` passes 75/75 (6 models, 69 tests).

## shops

**Rows:** 24
**Grain:** one row per shop
**Key:** shop_id (unique, never empty)

**Findings**
- Empty values only in retries_on_date (6, = retries never on) and three_ds_threshold_eur (16, = not an above_threshold shop), both allowed
- country NL/DE/FR, business_type 4 values, three_ds_policy 3 values; no spelling variants
- fee_pct 0.9–2.4 (percent); fixed_fee_eur 0–0.25 (0 = 2023 launch price for S12, S16, rulebook §6)
- Threshold is filled exactly for the 8 above_threshold shops

**Fixes needed in staging**
- None

**Tests to add**
- shop_id: unique, not_null
- not_null on all other columns except retries_on_date, three_ds_threshold_eur
- accepted_values: country, business_type, three_ds_policy
- *rule:* three_ds_threshold_eur is filled exactly when three_ds_policy = above_threshold

## banks

**Rows:** 3
**Grain:** one row per bank
**Key:** bank_id (unique, never empty)

**Findings**
- BNK_DE, BNK_FR, BNK_NL; no empty values

**Fixes needed in staging**
- None

**Tests to add**
- bank_id: unique, not_null
- not_null on bank_name, country
- accepted_values: country

## fee_rules

**Rows:** 21
**Grain:** one fee rule per bank × card type × region × period
**Key:** bank_id + card_type + region + valid_from (unique together)

**Findings**
- Empty values only in valid_to (18, = rule still valid), allowed
- card_type debit/credit; region domestic/other_eu/non_eu
- fee_pct 0.6–3.0 (percent); fixed_fee_eur 0.10–0.15
- Bank FR changed its credit fees on 1 Jul 2025, so those rules have an old and a new row

**Fixes needed in staging**
- None

**Tests to add**
- *rule:* unique combination of bank_id, card_type, region, valid_from
- not_null on all columns except valid_to
- accepted_values: card_type, region
- relationships: bank_id -> stg_banks

## payment_attempts

**Rows:** 106,130 (105,813 after removing duplicates)
**Grain:** one row per try to pay; payment_id groups a first try with its retries
**Key:** attempt_id, but only after removing duplicates

**Findings**
- 317 attempt_ids appear twice; all are exact copies
- Empty values only in decline_type (91,813, = try not declined), allowed
- card_country NL/DE/FR/ES/UK/US, card_type, initiated_by, outcome, decline_type: allowed values only
- amount_eur 4.99–4,000; attempted_at within 2025 (UTC)

**Surprises**
- attempt_id not unique (planted mess, rulebook §10)

**Fixes needed in staging**
- Remove exact duplicates with `SELECT DISTINCT *`. Otherwise 317 tries count twice.

**Tests to add**
- attempt_id: unique, not_null (after dedup)
- not_null on all columns except decline_type
- accepted_values: card_country, card_type, initiated_by, outcome, decline_type
  (accepted_values skips empty values, so decline_type passes on non-declined tries)
- relationships: shop_id -> stg_shops, bank_id -> stg_banks
- *rule:* decline_type is filled exactly when outcome = declined
- No unique test on payment_id: it repeats on purpose

## bank_payouts

**Rows:** 11,281
**Grain:** one payout per shop × bank × payment day
**Key:** payout_id (unique, never empty)

**Findings**
- No empty values; all 3 banks present
- payment_date within 2025; payout_date up to 2026-01-01 (late-December payments)
- payment_count 1–97; gross_eur 4.99–18,304.39; fees_eur 0.13–305.39

**Fixes needed in staging**
- None (checking payouts against payments is the Stage 5 exception list)

**Tests to add**
- payout_id: unique, not_null
- not_null on all columns
- relationships: shop_id -> stg_shops, bank_id -> stg_banks
- *rule:* unique combination of shop_id, bank_id, payment_date
- *rule:* net_eur = gross_eur - fees_eur on every row

## fraud_reports

**Rows:** 162
**Grain:** one row per reported payment
**Key:** fraud_report_id (unique, never empty)

**Findings**
- No empty values
- reported_date 2025-01-21 to 2026-01-27 (before the 31 Jan 2026 cut-off); amount_eur 4.99–1,335.57

**Surprises**
- Late-2025 fraud will look low because some reports arrive after the cut-off (rulebook §8)

**Checked later (2 Oct 2026)**
- amount_eur equals the reported try's amount_eur on all 162 reports
- All 162 reports point to an approved try

**Fixes needed in staging**
- None

**Tests to add**
- fraud_report_id: unique, not_null
- not_null on all columns
- relationships: attempt_id -> stg_payment_attempts
- *rule:* every report points to an approved try (compares two tables: custom SQL test)
