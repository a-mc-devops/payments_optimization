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
had gaps that would have become the project. A Python generator creates a year of
payments from written-down rules (see `docs/`), and also a hidden answer file that the
analysis never reads. At the end, the results are checked against those answers.

## Stack

Python (data generator) → BigQuery → dbt → Power BI

## Status

Planning complete. Data generation is next.
