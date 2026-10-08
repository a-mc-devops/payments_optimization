# Data model: the six raw tables

How the raw tables fit together: what one row means, what identifies it, and how tables connect.
Diagram: `images/erd.svg`.

## The tables

| Table | One row = | Rows | Key (identifies a row) | Points to |
| --- | --- | ---: | --- | --- |
| shops | one shop | 24 | `shop_id` | – |
| banks | one bank | 3 | `bank_id` | – |
| fee_rules | one bank's fee for one card type and card region, during one period | 21 | `bank_id` + `card_type` + `region` + `valid_from` | banks |
| payment_attempts | one try to pay (retries are extra rows) | 106,130 raw, 105,813 after removing duplicates | `attempt_id` (only after removing duplicates) | shops, banks |
| bank_payouts | one bank's payout for one shop's approved payments on one day (paid to the platform, rulebook §9) | 11,281 | `payout_id` (also unique: `shop_id` + `bank_id` + `payment_date`) | shops, banks |
| fraud_reports | one approved payment later reported as fraud | 162 | `fraud_report_id` | payment_attempts |

`payment_id` is not a key. It groups a first try with its retries, so it repeats on purpose
(105,813 tries belong to 100,141 payments).

## How the tables connect

**Linked by an ID** (solid lines in the diagram). Join on the column, no extra logic:

| From | To | Join on | How many |
| --- | --- | --- | --- |
| payment_attempts | shops | `shop_id` | many tries per shop |
| payment_attempts | banks | `bank_id` | many tries per bank |
| bank_payouts | shops | `shop_id` | many payouts per shop |
| bank_payouts | banks | `bank_id` | many payouts per bank |
| fee_rules | banks | `bank_id` | 6–9 rules per bank |
| fraud_reports | payment_attempts | `attempt_id` | 0 or 1 report per try |

**Matched by a rule** (dashed lines). There's no shared ID, so you match on several columns:

- **Try → fee rule:** same `bank_id` and `card_type`; `region` worked out from the card's country vs
  the **shop's** country (same = domestic; other NL/DE/FR/ES = other_eu; UK/US = non_eu); and the
  payment date between `valid_from` and `valid_to` (empty `valid_to` = still valid).
  Should give exactly one rule per approved try.
- **Tries → payout:** approved tries summed per shop, bank and approval day should equal one payout
  row (count, gross amount, fees). This is the Stage 5 comparison, and it's where wrong fees and
  missing payouts show up.

## Watch out when joining

- Remove the 317 duplicate tries first, or every join from `payment_attempts` counts them twice.
- One shop or bank joins to many rows. Join small tables onto big ones (tries → shops), not the
  other way round, or totals multiply.
- Fraud reports are a lower bound: reports arriving after 31 Jan 2026 are missing, so late 2025
  looks too low.
- Fee % columns are percents: 1.6 means 1.6%, so divide by 100 in calculations.
- Dates line up in UTC: all times are UTC and a payout's day is the approval day in UTC (rulebook §9),
  so `DATE(attempted_at)` matches `bank_payouts.payment_date` without any timezone conversion.
- `gave_up` tries carry a `bank_id` (the bank they would have gone to) but had no bank decision:
  don't count them as declined.
- `payment_id` repeats on purpose (a first try and its retries); never treat it as a key.

## Column names in staging

Rule: one column name = one meaning across all tables. A name that two joined tables share must mean
the same thing (join keys); anything else gets a prefix saying whose it is, or a join gives two
`country` columns and BigQuery stops with "column name is ambiguous".

All renames below are built (Stage 2, Oct 2026).

| Model | Raw name | Staging name | Why |
| --- | --- | --- | --- |
| stg_shops | `country` | `shop_country` | clashes with banks |
| stg_shops | `fee_pct`, `fixed_fee_eur` | `shop_fee_pct`, `shop_fixed_fee_eur` | clash with bank fees |
| stg_banks | `country` | `bank_country` | clashes with shops |
| stg_fee_rules | `fee_pct`, `fixed_fee_eur` | `bank_fee_pct`, `bank_fixed_fee_eur` | clash with shop prices |
| stg_fee_rules | `region` | `card_region` | the card's country vs the **shop's** country (rulebook §5) |
| stg_fraud_reports | `amount_eur` | `fraud_amount_eur` | clashes with `payment_attempts.amount_eur` |
| stg_bank_payouts | `fees_eur` | `bank_fees_eur` | "fees" alone could mean bank fee or shop price |

Kept as they are, because they mean the same thing in every table: `shop_id`, `bank_id`,
`attempt_id`, and `card_type` (payment_attempts joins fee_rules on it). `card_country` already
says whose it is.

## Turning the diagram into checks

Every part of the diagram suggests a check:

| In the diagram | Check to run |
| --- | --- |
| A key (PK) | unique and never empty |
| A solid line (FK) | every ID exists in the other table (LEFT JOIN … WHERE other.id IS NULL) |
| A dashed line | the rule match gives exactly one row, and counts and sums agree |
| A row count | does it match what the rulebook expects? |

In dbt, relationships tests point to the staging model (`stg_shops`), not to the raw source.
Rules between columns or tables need more than the four built-in tests; they are listed per table
under "Tests to add" in `docs/profiling_notes.md`.
