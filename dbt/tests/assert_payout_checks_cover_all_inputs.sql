WITH
    checks AS (
        SELECT
            COUNT(payout_id) AS payouts,
            SUM(expected_payment_count) AS payments
        FROM {{ ref('fct_payout_checks') }}
    )
    ,
    payouts_input AS (
        SELECT
            COUNT(*) AS payouts,
        FROM {{ ref('stg_bank_payouts') }}
    )
    ,
    payments_input AS (
        SELECT
            COUNT(*) AS payments
        FROM {{ ref('int_approved_payments')}}
    )

SELECT
    *
FROM checks, payouts_input, payments_input
WHERE checks.payouts != payouts_input.payouts OR checks.payments != payments_input.payments