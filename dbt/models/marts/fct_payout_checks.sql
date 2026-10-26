WITH
    expected AS (
        SELECT
            shop_id,
            bank_id,
            attempt_date AS payment_date,
            COUNT(*) AS expected_payment_count,
            SUM(amount_eur) AS expected_gross_eur,
            SUM(expected_bank_fee_eur) AS expected_bank_fee_eur
        FROM {{ ref('int_approved_payments') }}
        GROUP BY shop_id, bank_id, attempt_date
    ),

    payouts AS (
        SELECT
            payout_id,
            shop_id,
            bank_id,
            payment_date,
            payout_date,
            payment_count AS reported_payment_count,
            gross_eur AS reported_gross_eur,
            bank_fees_eur AS reported_bank_fee_eur
        FROM {{ ref('stg_bank_payouts') }}
    ),

    joined AS (
        SELECT
            COALESCE(ex.shop_id, py.shop_id) AS shop_id,
            COALESCE(ex.bank_id, py.bank_id) AS bank_id,
            COALESCE(ex.payment_date, py.payment_date) AS payment_date,
            py.payout_id,
            py.payout_date,
            ex.expected_payment_count,
            py.reported_payment_count,
            ex.expected_gross_eur,
            py.reported_gross_eur,
            ex.expected_bank_fee_eur,
            py.reported_bank_fee_eur
        FROM expected AS ex
        FULL OUTER JOIN payouts AS py
            ON ex.shop_id = py.shop_id
            AND ex.bank_id = py.bank_id
            AND ex.payment_date = py.payment_date
    )

SELECT
    shop_id,
    bank_id,
    payment_date,
    payout_id,
    payout_date,
    expected_payment_count,
    reported_payment_count,
    reported_payment_count - expected_payment_count AS payment_count_diff,
    expected_gross_eur,
    reported_gross_eur,
    reported_gross_eur - expected_gross_eur AS gross_diff_eur,
    expected_bank_fee_eur,
    reported_bank_fee_eur,
    reported_bank_fee_eur - expected_bank_fee_eur AS bank_fee_diff_eur,
    CASE
        WHEN payout_id IS NULL THEN 'missing_payout'
        WHEN expected_payment_count IS NULL THEN 'payout_without_payments'
        WHEN reported_payment_count != expected_payment_count
            OR reported_gross_eur != expected_gross_eur THEN 'count_or_amount_mismatch'
        WHEN ABS(reported_bank_fee_eur - expected_bank_fee_eur) > 0.01 * expected_payment_count THEN 'wrong_fee'
        ELSE 'matched'
    END AS check_result
FROM joined