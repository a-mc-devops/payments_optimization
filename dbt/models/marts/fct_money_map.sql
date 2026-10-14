WITH 
    sales_by_month AS(
    SELECT
        shop_id,
        DATE_TRUNC(attempt_date, MONTH) AS payment_month,
        COUNT(*) AS approved_payments_count,
        SUM(amount_eur) AS approved_sales_eur,
        SUM(shop_price_eur) AS shop_price_eur,
        SUM(expected_bank_fee_eur) AS expected_bank_fee_eur,
        SUM(guarantee_cost_eur) AS guarantee_cost_eur,
        SUM(platform_margin_eur) AS platform_margin_eur
    FROM {{ ref('int_approved_payments') }}
    GROUP BY shop_id, payment_month
    ),
    payments_by_month AS(
    SELECT
        shop_id,
        DATE_TRUNC(payment_date, MONTH) AS payment_month,
        COUNT(*) AS payments_count,
        SUM(CASE WHEN final_outcome = 'declined' THEN amount_eur ELSE 0 END) AS lost_to_declines_eur,
        SUM(CASE WHEN final_outcome = 'gave_up' THEN amount_eur ELSE 0 END) AS lost_to_give_ups_eur
    FROM {{ ref('int_payments') }}
    GROUP BY shop_id, payment_month
    )


SELECT
    py.shop_id,
    py.payment_month,
    py.payments_count,
    sl.approved_payments_count, 
    sl.approved_sales_eur,
    py.lost_to_declines_eur,
    py.lost_to_give_ups_eur,
    sl.shop_price_eur,
    sl.expected_bank_fee_eur,
    sl.guarantee_cost_eur,
    sl.platform_margin_eur
FROM payments_by_month AS py
LEFT JOIN sales_by_month AS sl
    ON py.shop_id = sl.shop_id
    AND py.payment_month = sl.payment_month