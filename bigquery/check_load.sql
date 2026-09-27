-- Checks that the six raw tables in BigQuery match the generated CSVs.
-- Run in the BigQuery console with project payments-optimization selected.
-- Every row should say PASS.
WITH checks AS (
  SELECT 1 AS n, 'shops: rows' AS check_name, CAST(COUNT(*) AS STRING) AS actual, '24' AS expected FROM raw.shops
  UNION ALL SELECT 2, 'banks: rows', CAST(COUNT(*) AS STRING), '3' FROM raw.banks
  UNION ALL SELECT 3, 'fee_rules: rows', CAST(COUNT(*) AS STRING), '21' FROM raw.fee_rules
  UNION ALL SELECT 4, 'payment_attempts: rows', CAST(COUNT(*) AS STRING), '106130' FROM raw.payment_attempts
  UNION ALL SELECT 5, 'bank_payouts: rows', CAST(COUNT(*) AS STRING), '11281' FROM raw.bank_payouts
  UNION ALL SELECT 6, 'fraud_reports: rows', CAST(COUNT(*) AS STRING), '162' FROM raw.fraud_reports
  UNION ALL SELECT 7, 'payment_attempts: distinct payment_id', CAST(COUNT(DISTINCT payment_id) AS STRING), '100141' FROM raw.payment_attempts
  UNION ALL SELECT 8, 'payment_attempts: distinct attempt_id', CAST(COUNT(DISTINCT attempt_id) AS STRING), '105813' FROM raw.payment_attempts
  UNION ALL SELECT 9, 'payment_attempts: sum amount_eur', CAST(SUM(amount_eur) AS STRING), '15209676.4' FROM raw.payment_attempts
  UNION ALL SELECT 10, 'payment_attempts: three_ds_used = true', CAST(COUNTIF(three_ds_used) AS STRING), '42492' FROM raw.payment_attempts
  UNION ALL SELECT 11, 'payment_attempts: decline_type is NULL', CAST(COUNTIF(decline_type IS NULL) AS STRING), '91813' FROM raw.payment_attempts
  UNION ALL SELECT 12, 'payment_attempts: first attempted_at', FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', MIN(attempted_at)), '2025-01-01 00:25:54' FROM raw.payment_attempts
  UNION ALL SELECT 13, 'payment_attempts: last attempted_at', FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', MAX(attempted_at)), '2025-12-31 23:30:24' FROM raw.payment_attempts
  UNION ALL SELECT 14, 'bank_payouts: sum gross_eur', CAST(SUM(gross_eur) AS STRING), '11503571.05' FROM raw.bank_payouts
  UNION ALL SELECT 15, 'bank_payouts: sum fees_eur', CAST(SUM(fees_eur) AS STRING), '176267.4' FROM raw.bank_payouts
  UNION ALL SELECT 16, 'bank_payouts: sum net_eur', CAST(SUM(net_eur) AS STRING), '11327303.65' FROM raw.bank_payouts
  UNION ALL SELECT 17, 'bank_payouts: sum payment_count', CAST(SUM(payment_count) AS STRING), '88494' FROM raw.bank_payouts
  UNION ALL SELECT 18, 'bank_payouts: first payment_date', CAST(MIN(payment_date) AS STRING), '2025-01-01' FROM raw.bank_payouts
  UNION ALL SELECT 19, 'bank_payouts: last payout_date', CAST(MAX(payout_date) AS STRING), '2026-01-01' FROM raw.bank_payouts
  UNION ALL SELECT 20, 'fraud_reports: sum amount_eur', CAST(SUM(amount_eur) AS STRING), '14870.01' FROM raw.fraud_reports
  UNION ALL SELECT 21, 'fraud_reports: last reported_date', CAST(MAX(reported_date) AS STRING), '2026-01-27' FROM raw.fraud_reports
  UNION ALL SELECT 22, 'shops: retries_on_date is NULL', CAST(COUNTIF(retries_on_date IS NULL) AS STRING), '6' FROM raw.shops
  UNION ALL SELECT 23, 'shops: three_ds_threshold_eur is NULL', CAST(COUNTIF(three_ds_threshold_eur IS NULL) AS STRING), '16' FROM raw.shops
  UNION ALL SELECT 24, 'shops: sum fee_pct', CAST(SUM(fee_pct) AS STRING), '43.4' FROM raw.shops
  UNION ALL SELECT 25, 'fee_rules: valid_to is NULL', CAST(COUNTIF(valid_to IS NULL) AS STRING), '18' FROM raw.fee_rules
  UNION ALL SELECT 26, 'fee_rules: sum fee_pct', CAST(SUM(fee_pct) AS STRING), '31.95' FROM raw.fee_rules
  UNION ALL SELECT 27, 'columns: total', CAST(COUNT(*) AS STRING), '45' FROM raw.INFORMATION_SCHEMA.COLUMNS
  UNION ALL SELECT 28, 'columns: STRING', CAST(COUNTIF(data_type = 'STRING') AS STRING), '25' FROM raw.INFORMATION_SCHEMA.COLUMNS
  UNION ALL SELECT 29, 'columns: NUMERIC', CAST(COUNTIF(data_type = 'NUMERIC') AS STRING), '10' FROM raw.INFORMATION_SCHEMA.COLUMNS
  UNION ALL SELECT 30, 'columns: DATE', CAST(COUNTIF(data_type = 'DATE') AS STRING), '6' FROM raw.INFORMATION_SCHEMA.COLUMNS
  UNION ALL SELECT 31, 'columns: INT64', CAST(COUNTIF(data_type = 'INT64') AS STRING), '2' FROM raw.INFORMATION_SCHEMA.COLUMNS
  UNION ALL SELECT 32, 'columns: TIMESTAMP', CAST(COUNTIF(data_type = 'TIMESTAMP') AS STRING), '1' FROM raw.INFORMATION_SCHEMA.COLUMNS
  UNION ALL SELECT 33, 'columns: BOOL', CAST(COUNTIF(data_type = 'BOOL') AS STRING), '1' FROM raw.INFORMATION_SCHEMA.COLUMNS
  -- Sandbox: every table gets a 60-day expiry, so 6 is expected. Use '0' if billing is enabled.
  UNION ALL SELECT 34, 'tables with an expiry date (sandbox)', CAST(COUNT(*) AS STRING), '6'
    FROM raw.INFORMATION_SCHEMA.TABLE_OPTIONS WHERE option_name = 'expiration_timestamp'
)
SELECT n, check_name, actual, expected, IF(actual = expected, 'PASS', 'FAIL') AS result
FROM checks
ORDER BY n;
