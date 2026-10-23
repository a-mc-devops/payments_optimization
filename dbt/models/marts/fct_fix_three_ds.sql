WITH give_up_rates AS (
    SELECT 
        business_type,
        COUNTIF(final_outcome = 'gave_up') / COUNT(*) AS give_up_rate
    FROM {{ ref('int_payments') }}
    WHERE three_ds_used IS TRUE
    GROUP BY business_type
    )
    ,
    shop_give_ups AS (
        SELECT
            shop_id,
            three_ds_policy,
            SUM(CASE WHEN final_outcome = 'gave_up' THEN amount_eur ELSE 0 END) AS give_up_sales_eur
        FROM {{ ref('int_payments') }}
        GROUP BY shop_id, three_ds_policy
    )
    ,
    base AS (
        SELECT
            sm.shop_id,
            sm.business_type,
            sg.three_ds_policy,
            sm.sales_without_3ds_eur AS unchecked_sales_eur,
            sm.approved_sales_eur - sm.sales_without_3ds_eur AS checked_sales_eur,
            sg.give_up_sales_eur,
            gr.give_up_rate,
            (sm.shop_price_eur - sm.expected_bank_fee_eur) / sm.approved_sales_eur * 100 AS margin_before_fraud_per_100_eur,
            fc.fraud_cost_per_100_eur_low,
            fc.fraud_cost_per_100_eur_best,
            fc.fraud_cost_per_100_eur_high
        FROM {{ ref('int_shop_margins') }} AS sm
        JOIN shop_give_ups AS sg ON sm.shop_id = sg.shop_id
        JOIN give_up_rates AS gr ON sm.business_type = gr.business_type
        JOIN {{ ref('int_fraud_cost_rates') }} AS fc ON sm.business_type = fc.business_type
    )

SELECT
    *,
    unchecked_sales_eur * fraud_cost_per_100_eur_low / 100
        - give_up_rate * unchecked_sales_eur * margin_before_fraud_per_100_eur / 100 AS check_every_platform_profit_eur_low,
    unchecked_sales_eur * fraud_cost_per_100_eur_best / 100
        - give_up_rate * unchecked_sales_eur * margin_before_fraud_per_100_eur / 100 AS check_every_platform_profit_eur_best,
    unchecked_sales_eur * fraud_cost_per_100_eur_high / 100
        - give_up_rate * unchecked_sales_eur * margin_before_fraud_per_100_eur / 100 AS check_every_platform_profit_eur_high,
    - give_up_rate * unchecked_sales_eur AS check_every_shop_sales_eur,
    give_up_sales_eur * margin_before_fraud_per_100_eur / 100
        - (checked_sales_eur + give_up_sales_eur) * fraud_cost_per_100_eur_high / 100 AS check_none_platform_profit_eur_low,
    give_up_sales_eur * margin_before_fraud_per_100_eur / 100
        - (checked_sales_eur + give_up_sales_eur) * fraud_cost_per_100_eur_best / 100 AS check_none_platform_profit_eur_best,
    give_up_sales_eur * margin_before_fraud_per_100_eur / 100
        - (checked_sales_eur + give_up_sales_eur) * fraud_cost_per_100_eur_low / 100 AS check_none_platform_profit_eur_high,
    give_up_sales_eur AS check_none_shop_sales_eur
FROM base