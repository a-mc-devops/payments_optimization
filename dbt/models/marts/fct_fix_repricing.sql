WITH own_fraud AS(
    SELECT
        shop_id,
        SUM(amount_eur) AS own_sales_without_3ds_eur,
        COUNTIF(fraud_report_id IS NOT NULL) AS own_fraud_case_count
    FROM
        {{ ref('int_approved_payments')}}
    WHERE attempt_date < DATE '{{ var("fraud_complete_before") }}' AND three_ds_used IS FALSE
    GROUP BY shop_id
    )
    ,
    base AS (
        SELECT
            sm.*,
            COALESCE(own.own_sales_without_3ds_eur, 0) AS jan_jul_sales_without_3ds_eur,
            COALESCE(own.own_fraud_case_count, 0) AS jan_jul_fraud_case_count,
            COALESCE(own.own_sales_without_3ds_eur, 0) / fc.sales_without_3ds_eur * fc.fraud_case_count AS expected_fraud_case_count,
            ((sm.expected_bank_fee_eur + sm.expected_fraud_cost_eur_high) - (sm.approved_payments_count * sm.shop_fixed_fee_eur)) / sm.approved_sales_eur * 100 AS safe_fee_pct
        FROM {{ ref('int_shop_margins') }} AS sm
        LEFT JOIN own_fraud AS own
            ON sm.shop_id = own.shop_id
        JOIN {{ ref('int_fraud_cost_rates') }} AS fc
            ON sm.business_type = fc.business_type
    )
    ,
    repriced AS(
        SELECT
            *,
            expected_margin_eur_best < 0 AS moves_to_safe_price,
            CASE WHEN expected_margin_eur_best < 0
                THEN (safe_fee_pct / 100 * approved_sales_eur + approved_payments_count * shop_fixed_fee_eur) - shop_price_eur
                ELSE 0
            END AS extra_price_income_eur
        FROM base
    )

SELECT
    *,
    jan_jul_fraud_case_count > expected_fraud_case_count + {{ var('standard_errors_in_range') }} * SQRT(expected_fraud_case_count) AS has_high_own_fraud,
    expected_margin_eur_best >= 0 AND expected_margin_eur_low < 0 AS is_loss_only_at_high_fraud,
    expected_margin_eur_low + extra_price_income_eur AS expected_margin_after_eur_low,
    expected_margin_eur_best + extra_price_income_eur AS expected_margin_after_eur_best,
    expected_margin_eur_high + extra_price_income_eur AS expected_margin_after_eur_high,
FROM repriced