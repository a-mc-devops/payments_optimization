# Payments Optimization

Where does a payments platform lose money, and which fixes recover the most?

A fictional EU payments platform processes card payments for 24 shops. Money leaks in four
places:

- **Declined cards**: the customer wanted to pay, the sale was lost.
- **Bank fees**: some payments are routed to a more expensive bank than necessary.
- **Fraud**: stolen-card payments that are later reported and refunded.
- **Underpriced shops**: shops paying the platform less than their payments cost it.

The project measures each leak per shop and month, estimates what each fix is worth per
year (bank choice, retrying declined payments, repricing shops, the 3D Secure security
check), and ranks the actions for a Head of Payments.

## About the data

The data is simulated. Real payment data is never published, and public practice datasets
had gaps that would have become the project. A Python generator creates a year of payments
(2025) from written-down rules in [`docs/rulebook.md`](docs/rulebook.md), plus a hidden
answer file that the analysis never reads. Its SHA-256 fingerprint was committed before any
analysis started ([`docs/answers_sha256.txt`](docs/answers_sha256.txt)). At the end, the
results are checked against those answers.

| Table | One row = | Rows |
| --- | --- | ---: |
| shops | shop | 24 |
| banks | bank | 3 |
| fee_rules | bank x card type x region x period | 21 |
| payment_attempts | one try to pay (retries are separate rows) | 106,130 |
| bank_payouts | shop x bank x payment day | 11,281 |
| fraud_reports | payment later reported as fraud | 162 |

The data includes realistic mess on purpose: duplicate rows, fraud reports that arrive
late, and one bank's payouts with wrong fees.

Rebuild the data (the fixed seed gives identical files):

```
pip install -r python/requirements.txt
python python/generate_data.py
python python/check_generated_data.py
```

## Repository

- `docs/`: rulebook and the answer-file fingerprint
- `python/`: data generator and checks
- `bigquery/`: table schemas, load guide and load check
- `data/`: generated files (not in git)

## Stack

Python (data generator) → BigQuery → dbt → Power BI

## Status

Stage 1 of 7 complete: data generated, checked and loaded into BigQuery. Next: dbt models.
