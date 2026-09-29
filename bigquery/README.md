# Loading the raw data into BigQuery

Google Cloud project: `payments-optimization`. Dataset: `raw` (the six CSVs exactly as generated).
dbt will later write its own datasets next to it; all must use the same location.

## 1. Create the dataset (once)

BigQuery console → your project → **Create dataset**:

| Setting | Value | Why |
|---|---|---|
| Dataset ID | `raw` | Untouched source tables; dbt reads from here |
| Location type | Multi-region → **EU** | Cannot be changed later; every dbt dataset must match |
| Default table expiration | Off | Tables must not disappear (see sandbox note) |
| Everything else | Default | |

Sandbox: this project runs in the free BigQuery sandbox (decided 25 Sep 2026). Every table
expires 60 days after it is created (the first load expires on 24 Nov 2026), and
INSERT/UPDATE/DELETE/MERGE are blocked. If the tables expire, repeat step 2 and rebuild with dbt.

## 2. Load each CSV (6 times)

Dataset `raw` → **Create table**:

| Setting | Value |
|---|---|
| Create table from | Upload → pick `data/raw/<table>.csv` |
| File format | CSV |
| Table | same name as the file, without `.csv` |
| Schema | Auto detect **off** → **Edit as text** → paste `bigquery/schemas/<table>.json` |
| Partitioning / clustering | None (the tables are tiny) |
| Advanced → Write preference | Write if empty (use Overwrite table only for a deliberate reload) |
| Advanced → Number of errors allowed | 0 |
| Advanced → Header rows to skip | 1 |
| Advanced → Field delimiter | Comma |

Why explicit schemas instead of auto-detect: money columns load as exact `NUMERIC`
(auto-detect picks `FLOAT64`, which adds tiny rounding errors to sums and payout matching),
and mostly-empty columns such as `valid_to` or `three_ds_threshold_eur` get the right type.
Column order in each schema file matches the CSV header; BigQuery matches columns by position.
Empty cells load as NULL.

## 3. Check the load

```sql
SELECT 'shops' AS table_name, COUNT(*) AS rows_loaded FROM raw.shops UNION ALL
SELECT 'banks', COUNT(*) FROM raw.banks UNION ALL
SELECT 'fee_rules', COUNT(*) FROM raw.fee_rules UNION ALL
SELECT 'payment_attempts', COUNT(*) FROM raw.payment_attempts UNION ALL
SELECT 'bank_payouts', COUNT(*) FROM raw.bank_payouts UNION ALL
SELECT 'fraud_reports', COUNT(*) FROM raw.fraud_reports;
```

Expected: shops 24, banks 3, fee_rules 21, payment_attempts 106,130, bank_payouts 11,281,
fraud_reports 162.

For the full check (row counts, totals, dates, empty values, column types, expiry) run
`bigquery/check_load.sql`; every row should say PASS. First load on 25 Sep 2026: 34/34 PASS.

Never upload `data/answers/` or `data/xlsx/`.
