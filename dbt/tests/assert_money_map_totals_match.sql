WITH 
    map AS(
        SELECT
            SUM(payments_count) AS payments,
            SUM(lost_to_declines_eur) AS declines,
            SUM(lost_to_give_ups_eur) AS give_ups,
            SUM(approved_payments_count) AS approved_payments,
            SUM(approved_sales_eur) AS sales_eur,
            SUM(platform_margin_eur) AS margin_eur
        FROM {{ ref('fct_money_map') }}
    ),

    payments AS(
        SELECT
            COUNT(*) AS payments,
            SUM(CASE WHEN final_outcome = 'declined' THEN amount_eur ELSE 0 END) AS declines,
            SUM(CASE WHEN final_outcome = 'gave_up' THEN amount_eur ELSE 0 END) AS give_ups,
        FROM {{ ref('int_payments') }}
    ),

    sales AS(
        SELECT
            COUNT(*) AS approved_payments,
            SUM(amount_eur) AS sales_eur,
            SUM(platform_margin_eur) AS margin_eur
        FROM {{ ref('int_approved_payments') }}
    )

SELECT
    *
FROM map, payments, sales
WHERE
    map.payments != payments.payments
    OR
    map.declines != payments.declines
    OR
    map.give_ups != payments.give_ups
    OR
    map.approved_payments != sales.approved_payments
    OR
    map.sales_eur != sales.sales_eur
    OR
    map.margin_eur != sales.margin_eur